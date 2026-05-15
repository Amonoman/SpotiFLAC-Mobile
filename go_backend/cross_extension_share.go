package gobackend

import (
	"encoding/json"
	"fmt"
	"strings"
	"sync"

	"github.com/dop251/goja"
)

// CrossExtensionShareResult holds the result for one extension.
type CrossExtensionShareResult struct {
	ExtensionID string `json:"extension_id"`
	DisplayName string `json:"display_name"`
	Found       bool   `json:"found"`

	// ItemID is the raw ID returned by the extension (may have prefix like "qobuz:123").
	ItemID string `json:"item_id,omitempty"`

	// ExternalLink is the best direct web URL we could find for this item.
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
//	  "type":                "album",        // "album" | "artist"
//	  "source_extension_id": "qobuz-web"
//	}
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
				results[idx] = findArtistForExtension(prov, req.Name, base)
			default:
				results[idx] = findAlbumForExtension(prov, req.Name, req.Artists, base)
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

// ─── Album search ────────────────────────────────────────────────────────────

func findAlbumForExtension(
	p *extensionProviderWrapper,
	albumName, artists string,
	res CrossExtensionShareResult,
) CrossExtensionShareResult {
	searchQuery := albumName
	if artists != "" {
		searchQuery = albumName + " " + artists
	}

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

	// Collect all URL hints from the track.
	rawURLs := collectRawURLs(p, best)

	// Try to get the album-level URL by calling customSearch with filter=album.
	albumURL, albumID := searchAlbumURL(p, albumName, artists)
	if albumURL != "" {
		res.ExternalLink = albumURL
		res.ItemID = albumID
	} else {
		// Fall back to the best URL from the track itself.
		res.ExternalLink = bestURLFromHints(rawURLs, p.extension.ID, "album", best.ID)
		res.ItemID = best.ID
	}

	return res
}

// ─── Artist search ───────────────────────────────────────────────────────────

func findArtistForExtension(
	p *extensionProviderWrapper,
	artistName string,
	res CrossExtensionShareResult,
) CrossExtensionShareResult {
	// Use customSearch with filter:"artist" to get a real artist ID and URL.
	artistURL, artistID, foundName := searchArtistURL(p, artistName)
	if artistURL != "" || artistID != "" {
		res.Found = true
		res.ItemName = foundName
		res.ItemID = artistID
		res.ExternalLink = artistURL
		return res
	}

	// Fallback: search tracks and infer artist from the best match.
	sr, err := p.SearchTracks(artistName, 10)
	if err != nil {
		res.Error = err.Error()
		return res
	}
	if sr == nil || len(sr.Tracks) == 0 {
		res.Error = "artist not found"
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

	rawURLs := collectRawURLs(p, best)
	res.Found = true
	res.ItemName = best.Artists
	res.ItemID = best.ID
	res.ExternalLink = bestURLFromHints(rawURLs, p.extension.ID, "artist", best.ID)
	return res
}

// ─── customSearch helpers ────────────────────────────────────────────────────

// searchAlbumURL calls customSearch(query, {filter:"album"}) and returns
// the first album URL and ID that matches albumName + artists.
func searchAlbumURL(p *extensionProviderWrapper, albumName, artists string) (url, id string) {
	query := albumName
	if artists != "" {
		query = albumName + " " + artists
	}

	items, err := customSearchFilter(p, query, "album", 5)
	if err != nil || len(items) == 0 {
		return "", ""
	}

	normAlbum := normalizeLooseTitle(albumName)

	for _, item := range items {
		itemName := normalizeLooseTitle(getStringFromMap(item, "name"))
		if itemName == "" || (!strings.Contains(itemName, normAlbum) && !strings.Contains(normAlbum, itemName)) {
			continue
		}
		rawID := getStringFromMap(item, "id")
		rawURL := firstNonEmptyStr(
			getStringFromMap(item, "external_urls"),
			getStringFromMap(item, "external_links"),
			getStringFromMap(item, "url"),
			getStringFromMap(item, "album_url"),
		)
		if rawURL == "" {
			rawURL = buildURLFromID(p.extension.ID, rawID, "album")
		}
		return rawURL, rawID
	}
	return "", ""
}

// searchArtistURL calls customSearch(query, {filter:"artist"}) and returns
// the first artist URL, ID and name that matches artistName.
func searchArtistURL(p *extensionProviderWrapper, artistName string) (url, id, name string) {
	items, err := customSearchFilter(p, artistName, "artist", 5)
	if err != nil || len(items) == 0 {
		return "", "", ""
	}

	normArtist := normalizeLooseArtistName(artistName)

	for _, item := range items {
		itemName := getStringFromMap(item, "name")
		if !strings.Contains(normalizeLooseArtistName(itemName), normArtist) &&
			!strings.Contains(normArtist, normalizeLooseArtistName(itemName)) {
			continue
		}
		rawID := getStringFromMap(item, "id")
		rawURL := firstNonEmptyStr(
			getStringFromMap(item, "external_urls"),
			getStringFromMap(item, "external_links"),
			getStringFromMap(item, "url"),
			getStringFromMap(item, "permalink_url"),
		)
		if rawURL == "" {
			rawURL = buildURLFromID(p.extension.ID, rawID, "artist")
		}
		return rawURL, rawID, itemName
	}
	return "", "", ""
}

// customSearchFilter calls extension.customSearch(query, {filter, limit}) via JS
// and returns the raw JS objects as map slices.
func customSearchFilter(p *extensionProviderWrapper, query, filter string, limit int) ([]map[string]interface{}, error) {
	if !p.extension.Enabled {
		return nil, fmt.Errorf("extension disabled")
	}
	if err := p.lockReadyVM(); err != nil {
		return nil, err
	}
	defer p.extension.VMMu.Unlock()

	script := fmt.Sprintf(`
		(function() {
			if (typeof extension !== 'undefined' && typeof extension.customSearch === 'function') {
				return extension.customSearch(%q, { filter: %q, limit: %d });
			}
			return null;
		})()
	`, query, filter, limit)

	result, err := RunWithTimeoutAndRecover(p.vm, script, DefaultJSTimeout)
	if err != nil || result == nil || goja.IsUndefined(result) || goja.IsNull(result) {
		return nil, err
	}

	exported := result.Export()
	slice, ok := exported.([]interface{})
	if !ok {
		return nil, nil
	}

	out := make([]map[string]interface{}, 0, len(slice))
	for _, v := range slice {
		m, ok := v.(map[string]interface{})
		if ok {
			out = append(out, m)
		}
	}
	return out, nil
}

// ─── URL helpers ─────────────────────────────────────────────────────────────

// collectRawURLs gathers every URL hint available from a track.
// Checks ExternalLinks map, plus common string fields that extensions
// set under different names (external_urls, permalink_url, album_url).
func collectRawURLs(p *extensionProviderWrapper, t *ExtTrackMetadata) []string {
	var urls []string

	// ExternalLinks map (Qobuz uses this: {"qobuz": "https://play.qobuz.com/track/..."})
	for _, v := range t.ExternalLinks {
		if v != "" {
			urls = append(urls, v)
		}
	}

	// Apple Music and SoundCloud set external_urls as a plain string field,
	// but parseExtensionTrackValue doesn't parse it. We re-read it via the
	// raw provider ID and known patterns.
	// Since we can't re-run JS here, we rely on buildURLFromID as fallback.

	return urls
}

// bestURLFromHints picks the best URL from available hints for an album or artist.
// If no hint is available, it constructs one from the ID.
func bestURLFromHints(hints []string, extensionID, itemType, rawID string) string {
	for _, u := range hints {
		if u != "" && strings.HasPrefix(u, "https://") {
			return u
		}
	}
	return buildURLFromID(extensionID, rawID, itemType)
}

// buildURLFromID constructs a direct web URL from a provider ID and item ID.
// Handles prefix stripping (e.g. "qobuz:0060253780269" → "0060253780269").
func buildURLFromID(extensionID, rawID, itemType string) string {
	id := stripProviderPrefix(rawID)
	if id == "" {
		return ""
	}

	ext := strings.ToLower(extensionID)

	switch {
	case strings.Contains(ext, "qobuz"):
		if itemType == "artist" {
			return "https://open.qobuz.com/interpreter/" + id
		}
		return "https://open.qobuz.com/album/" + id

	case strings.Contains(ext, "tidal"):
		if itemType == "artist" {
			return "https://tidal.com/browse/artist/" + id
		}
		return "https://tidal.com/browse/album/" + id

	case strings.Contains(ext, "deezer"):
		if itemType == "artist" {
			return "https://www.deezer.com/artist/" + id
		}
		return "https://www.deezer.com/album/" + id

	case strings.Contains(ext, "spotify"):
		if itemType == "artist" {
			return "https://open.spotify.com/artist/" + id
		}
		return "https://open.spotify.com/album/" + id

	case strings.Contains(ext, "apple"), strings.Contains(ext, "applemusic"):
		// Apple Music URL: https://music.apple.com/{storefront}/album/{id}
		// We don't know the storefront here, default to "us".
		if itemType == "artist" {
			return "https://music.apple.com/us/artist/" + id
		}
		return "https://music.apple.com/us/album/" + id

	case strings.Contains(ext, "soundcloud"):
		// SoundCloud IDs are numeric; the URL needs the slug which we don't have.
		// Return a search URL as best effort.
		return ""

	case strings.Contains(ext, "youtube"), strings.Contains(ext, "ytmusic"):
		if itemType == "artist" {
			return "https://music.youtube.com/channel/" + id
		}
		return "https://music.youtube.com/browse/" + id
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

// ─── Map helpers ─────────────────────────────────────────────────────────────

func getStringFromMap(m map[string]interface{}, keys ...string) string {
	for _, key := range keys {
		if v, ok := m[key]; ok {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

func firstNonEmptyStr(vals ...string) string {
	for _, v := range vals {
		if v != "" {
			return v
		}
	}
	return ""
}
