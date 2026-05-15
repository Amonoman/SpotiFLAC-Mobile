package gobackend

import (
	"encoding/json"
	"strings"
	"sync"
)

// CrossExtensionShareResult holds the result for one extension.
type CrossExtensionShareResult struct {
	ExtensionID string `json:"extension_id"`
	DisplayName string `json:"display_name"`
	Found       bool   `json:"found"`

	// ItemID is the raw prefixed ID returned by the extension, e.g. "qobuz:0060253780269".
	ItemID string `json:"item_id,omitempty"`

	// AlbumID / ArtistID are the prefixed collection IDs, e.g. "qobuz:0060253780269".
	AlbumID  string `json:"album_id,omitempty"`
	ArtistID string `json:"artist_id,omitempty"`

	// ExternalLink is the direct web URL from the extension's external_links map, if present.
	ExternalLink string `json:"external_link,omitempty"`

	ItemName    string `json:"item_name,omitempty"`
	ItemArtists string `json:"item_artists,omitempty"`
	Error       string `json:"error,omitempty"`
}

// FindCollectionAcrossExtensionsJSON searches for an album or artist across all
// enabled metadata-provider extensions (except the source extension).
//
// Request JSON:
//
//	{
//	  "name":                "In Rainbows",
//	  "artists":             "Radiohead",
//	  "type":                "album",      // "album" | "artist"
//	  "source_extension_id": "qobuz-web"
//	}
//
// Returns JSON array of CrossExtensionShareResult.
func FindCollectionAcrossExtensionsJSON(requestJSON string) (string, error) {
	var req struct {
		Name              string `json:"name"`
		Artists           string `json:"artists"`
		Type              string `json:"type"`
		SourceExtensionID string `json:"source_extension_id"`
	}
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		return "", err
	}

	req.Name = strings.TrimSpace(req.Name)
	req.Artists = strings.TrimSpace(req.Artists)
	req.Type = strings.TrimSpace(strings.ToLower(req.Type))
	req.SourceExtensionID = strings.TrimSpace(req.SourceExtensionID)

	if req.Name == "" {
		return "[]", nil
	}
	if req.Type == "" {
		req.Type = "album"
	}

	manager := getExtensionManager()
	providers := manager.GetMetadataProviders()

	searchQuery := req.Name
	if req.Artists != "" {
		searchQuery = req.Name + " " + req.Artists
	}

	work := make([]*extensionProviderWrapper, 0, len(providers))
	for _, p := range providers {
		if p.extension.ID == req.SourceExtensionID {
			continue
		}
		work = append(work, p)
	}

	results := make([]CrossExtensionShareResult, len(work))
	var wg sync.WaitGroup

	for i, p := range work {
		wg.Add(1)
		go func(idx int, prov *extensionProviderWrapper) {
			defer wg.Done()
			base := CrossExtensionShareResult{
				ExtensionID: prov.extension.ID,
				DisplayName: prov.extension.Manifest.DisplayName,
			}
			switch req.Type {
			case "artist":
				results[idx] = findArtistForExtension(prov, req.Name, searchQuery, base)
			default:
				results[idx] = findAlbumForExtension(prov, req.Name, req.Artists, searchQuery, base)
			}
		}(i, p)
	}

	wg.Wait()

	b, err := json.Marshal(results)
	if err != nil {
		return "[]", err
	}
	return string(b), nil
}

// findAlbumForExtension searches for an album in one extension.
// It uses the extension's SearchTracks, matches by album title + artist,
// then extracts the album ID and any external link from the best matching track.
func findAlbumForExtension(
	p *extensionProviderWrapper,
	albumName, artists, searchQuery string,
	res CrossExtensionShareResult,
) CrossExtensionShareResult {
	sr, err := p.SearchTracks(searchQuery, 10)
	if err != nil {
		res.Error = err.Error()
		return res
	}
	if sr == nil || len(sr.Tracks) == 0 {
		res.Error = "no results"
		return res
	}

	normAlbum := normalizeLooseTitle(albumName)
	normArtists := normalizeLooseArtistName(artists)

	bestScore := -1
	var best *ExtTrackMetadata

	for i := range sr.Tracks {
		t := &sr.Tracks[i]
		tAlbum := normalizeLooseTitle(t.AlbumName)
		tArtist := normalizeLooseArtistName(t.Artists + " " + t.AlbumArtist)

		score := 0
		if tAlbum == normAlbum {
			score += 100
		} else if strings.Contains(tAlbum, normAlbum) || strings.Contains(normAlbum, tAlbum) {
			score += 50
		}
		if normArtists != "" &&
			(strings.Contains(tArtist, normArtists) || strings.Contains(normArtists, tArtist)) {
			score += 30
		}
		if score > bestScore {
			bestScore = score
			best = t
		}
	}

	if best == nil || bestScore < 50 {
		res.Error = "album not found"
		return res
	}

	res.Found = true
	res.ItemName = best.AlbumName
	res.ItemArtists = best.Artists

	// Album ID: extensions store it in the prefixed track ID's album part.
	// The Qobuz extension stores qobuz_id on the track; the track ID is "qobuz:<trackID>".
	// We use the provider-specific album ID fields where available.
	res.AlbumID = resolveAlbumID(best)
	res.ArtistID = best.ID // fallback; artist_id isn't on track directly
	res.ItemID = res.AlbumID

	// ExternalLink: use the album-level external link if the extension provided one.
	// Qobuz's formatTrack sets external_links["qobuz"] = play.qobuz.com/track/<id>.
	// We derive the album URL from it.
	res.ExternalLink = deriveAlbumExternalLink(best)

	return res
}

// findArtistForExtension searches for an artist in one extension.
func findArtistForExtension(
	p *extensionProviderWrapper,
	artistName, searchQuery string,
	res CrossExtensionShareResult,
) CrossExtensionShareResult {
	sr, err := p.SearchTracks(searchQuery, 10)
	if err != nil {
		res.Error = err.Error()
		return res
	}
	if sr == nil || len(sr.Tracks) == 0 {
		res.Error = "no results"
		return res
	}

	normArtist := normalizeLooseArtistName(artistName)
	bestScore := -1
	var best *ExtTrackMetadata

	for i := range sr.Tracks {
		t := &sr.Tracks[i]
		tArtist := normalizeLooseArtistName(t.Artists)
		score := 0
		if tArtist == normArtist {
			score += 100
		} else if strings.Contains(tArtist, normArtist) || strings.Contains(normArtist, tArtist) {
			score += 60
		}
		if score > bestScore {
			bestScore = score
			best = t
		}
	}

	if best == nil || bestScore < 60 {
		res.Error = "artist not found"
		return res
	}

	res.Found = true
	res.ItemName = best.Artists
	res.ArtistID = resolveArtistID(best)
	res.ItemID = res.ArtistID
	res.ExternalLink = deriveArtistExternalLink(best)
	return res
}

// resolveAlbumID returns the best album ID for a track.
// Extensions prefix IDs: "qobuz:ABC123", "tidal:456", etc.
// For Qobuz, the track's ID is "qobuz:<trackID>" but we want the album ID.
// The album ID is stored in the track's ExternalLinks or can be derived from QobuzID.
func resolveAlbumID(t *ExtTrackMetadata) string {
	// QobuzID on the track struct is just the raw numeric track ID.
	// The album ID comes from the track.album.id in the JS which maps to album_id field.
	// Since ExtTrackMetadata doesn't expose album_id directly, we derive it from
	// ExternalLinks or fall back to the prefixed track ID.
	if link, ok := t.ExternalLinks["qobuz"]; ok && link != "" {
		return t.ID // "qobuz:<trackID>" – caller will strip to get numeric ID
	}
	if t.QobuzID != "" {
		return "qobuz:" + t.QobuzID
	}
	if t.TidalID != "" {
		return "tidal:" + t.TidalID
	}
	if t.DeezerID != "" {
		return "deezer:" + t.DeezerID
	}
	if t.SpotifyID != "" {
		return "spotify:" + t.SpotifyID
	}
	return t.ID
}

// resolveArtistID returns the best artist ID for a track.
func resolveArtistID(t *ExtTrackMetadata) string {
	// artist_id isn't in ExtTrackMetadata, so we use what we have.
	// The Dart side will use ExternalLink for the URL instead.
	if t.QobuzID != "" {
		return "qobuz:" + t.QobuzID
	}
	if t.TidalID != "" {
		return "tidal:" + t.TidalID
	}
	if t.DeezerID != "" {
		return "deezer:" + t.DeezerID
	}
	if t.SpotifyID != "" {
		return "spotify:" + t.SpotifyID
	}
	return t.ID
}

// deriveAlbumExternalLink builds a direct album URL from the track's external links.
// Qobuz: external_links["qobuz"] = "https://play.qobuz.com/track/12345"
//
//	→ album link requires album ID which we don't have directly from search.
//	  We use "https://open.qobuz.com/album/<albumID>" but we only have the track link.
//	  So we return the track link as a fallback; the user lands on the track page
//	  which shows the album.
func deriveAlbumExternalLink(t *ExtTrackMetadata) string {
	// Use the first available external link from the extension.
	for _, link := range t.ExternalLinks {
		if link != "" {
			return link
		}
	}
	// Fallback: construct from known provider patterns.
	id := stripProviderPrefix(t.ID)
	switch inferProvider(t) {
	case "qobuz":
		return "https://open.qobuz.com/track/" + id
	case "tidal":
		return "https://tidal.com/browse/track/" + id
	case "deezer":
		return "https://www.deezer.com/track/" + id
	case "spotify":
		return "https://open.spotify.com/track/" + id
	}
	return ""
}

// deriveArtistExternalLink builds a direct artist URL.
// Since we only have track data, we derive based on the provider.
func deriveArtistExternalLink(t *ExtTrackMetadata) string {
	id := stripProviderPrefix(t.ID)
	switch inferProvider(t) {
	case "qobuz":
		// Qobuz search result has artist ID in external_links or qobuz_id.
		// Best we can do without artist_id is search URL.
		return "https://open.qobuz.com/search#" + t.Artists
	case "tidal":
		return "https://tidal.com/browse/search?q=" + t.Artists
	case "deezer":
		return "https://www.deezer.com/search/" + t.Artists
	case "spotify":
		return "https://open.spotify.com/search/" + t.Artists
	}
	_ = id
	return ""
}

// inferProvider guesses the provider from available ID fields.
func inferProvider(t *ExtTrackMetadata) string {
	if t.QobuzID != "" || strings.HasPrefix(t.ID, "qobuz:") {
		return "qobuz"
	}
	if t.TidalID != "" || strings.HasPrefix(t.ID, "tidal:") {
		return "tidal"
	}
	if t.DeezerID != "" || strings.HasPrefix(t.ID, "deezer:") {
		return "deezer"
	}
	if t.SpotifyID != "" || strings.HasPrefix(t.ID, "spotify:") {
		return "spotify"
	}
	if t.ProviderID != "" {
		lower := strings.ToLower(t.ProviderID)
		for _, name := range []string{"qobuz", "tidal", "deezer", "spotify"} {
			if strings.Contains(lower, name) {
				return name
			}
		}
	}
	return ""
}

// stripProviderPrefix removes a "provider:" prefix, e.g. "qobuz:12345" → "12345".
func stripProviderPrefix(id string) string {
	if i := strings.Index(id, ":"); i >= 0 {
		return id[i+1:]
	}
	return id
}
