package gobackend

import (
	"strings"
	"unicode"

	"golang.org/x/text/unicode/norm"
)

func writeNormalizedArtistRune(b *strings.Builder, r rune) {
	switch r {
	case 'đ':
		b.WriteString("dj")
	case 'ß':
		b.WriteString("ss")
	case 'æ':
		b.WriteString("ae")
	case 'œ':
		b.WriteString("oe")
	default:
		b.WriteRune(r)
	}
}

func normalizeLooseTitle(title string) string {
	trimmed := strings.TrimSpace(strings.ToLower(title))
	if trimmed == "" {
		return ""
	}

	var b strings.Builder
	b.Grow(len(trimmed))

	for _, r := range trimmed {
		switch {
		case unicode.IsLetter(r), unicode.IsNumber(r):
			b.WriteRune(r)
		case unicode.IsSpace(r):
			b.WriteByte(' ')
		case r == '/', r == '\\', r == '_', r == '-', r == '|', r == '.', r == '&', r == '+':
			b.WriteByte(' ')
		default:
		}
	}

	return strings.Join(strings.Fields(b.String()), " ")
}

func normalizeLooseArtistName(name string) string {
	trimmed := strings.TrimSpace(strings.ToLower(name))
	if trimmed == "" {
		return ""
	}

	decomposed := norm.NFD.String(trimmed)

	var b strings.Builder
	b.Grow(len(decomposed))

	for _, r := range decomposed {
		switch {
		case unicode.Is(unicode.Mn, r), unicode.Is(unicode.Mc, r), unicode.Is(unicode.Me, r):
			continue
		case unicode.IsLetter(r), unicode.IsNumber(r):
			writeNormalizedArtistRune(&b, r)
		case unicode.IsSpace(r):
			b.WriteByte(' ')
		case r == '/', r == '\\', r == '_', r == '-', r == '|', r == '.', r == '&', r == '+':
			b.WriteByte(' ')
		default:
		}
	}

	return strings.Join(strings.Fields(b.String()), " ")
}

func hasAlphaNumericRunes(value string) bool {
	for _, r := range value {
		if unicode.IsLetter(r) || unicode.IsNumber(r) {
			return true
		}
	}
	return false
}

func normalizeSymbolOnlyTitle(title string) string {
	trimmed := strings.TrimSpace(strings.ToLower(title))
	if trimmed == "" {
		return ""
	}

	var b strings.Builder
	b.Grow(len(trimmed))

	for _, r := range trimmed {
		switch {
		case unicode.IsLetter(r), unicode.IsNumber(r), unicode.IsSpace(r), unicode.IsPunct(r):
			continue
		// Drop combining marks such as emoji variation selectors.
		case unicode.Is(unicode.Mn, r), unicode.Is(unicode.Mc, r), unicode.Is(unicode.Me, r):
			continue
		default:
			b.WriteRune(r)
		}
	}

	return b.String()
}

type resolvedTrackInfo struct {
	Title                string
	ArtistName           string
	ISRC                 string
	Duration             int
	SkipNameVerification bool
}

func trackMatchesRequest(req DownloadRequest, resolved resolvedTrackInfo, logPrefix string) bool {
	exactISRCMatch := req.ISRC != "" &&
		resolved.ISRC != "" &&
		strings.EqualFold(strings.TrimSpace(req.ISRC), strings.TrimSpace(resolved.ISRC))

	if !exactISRCMatch && !resolved.SkipNameVerification {
		if req.ArtistName != "" && resolved.ArtistName != "" &&
			!artistsMatch(req.ArtistName, resolved.ArtistName) {
			GoLog("[%s] Verification failed: artist mismatch — expected '%s', got '%s'\n",
				logPrefix, req.ArtistName, resolved.ArtistName)
			return false
		}

		if req.TrackName != "" && resolved.Title != "" &&
			!titlesMatch(req.TrackName, resolved.Title) {
			GoLog("[%s] Verification failed: title mismatch — expected '%s', got '%s'\n",
				logPrefix, req.TrackName, resolved.Title)
			return false
		}
	}

	expectedDurationSec := req.DurationMS / 1000
	if expectedDurationSec > 0 && resolved.Duration > 0 {
		diff := expectedDurationSec - resolved.Duration
		if diff < 0 {
			diff = -diff
		}
		if diff > 10 {
			GoLog("[%s] Verification failed: duration mismatch — expected %ds, got %ds\n",
				logPrefix, expectedDurationSec, resolved.Duration)
			return false
		}
	}

	return true
}
