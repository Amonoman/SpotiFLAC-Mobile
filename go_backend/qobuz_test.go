package gobackend

import "testing"

func TestExtractQobuzDownloadURLFromBody(t *testing.T) {
	t.Run("reads top-level download_url and quality metadata", func(t *testing.T) {
		body := []byte(`{"success":true,"download_url":"https://example.test/new.flac","bit_depth":24,"sampling_rate":96}`)

		info, err := extractQobuzDownloadInfoFromBody(body)
		if err != nil {
			t.Fatalf("expected no error, got %v", err)
		}
		if info.DownloadURL != "https://example.test/new.flac" {
			t.Fatalf("unexpected URL: %q", info.DownloadURL)
		}
		if info.BitDepth != 24 {
			t.Fatalf("unexpected bit depth: %d", info.BitDepth)
		}
		if info.SampleRate != 96000 {
			t.Fatalf("unexpected sample rate: %d", info.SampleRate)
		}
	})

	t.Run("reads nested data.url", func(t *testing.T) {
		body := []byte(`{"success":true,"data":{"url":"https://example.test/audio.flac"}}`)

		got, err := extractQobuzDownloadURLFromBody(body)
		if err != nil {
			t.Fatalf("expected no error, got %v", err)
		}
		if got != "https://example.test/audio.flac" {
			t.Fatalf("unexpected URL: %q", got)
		}
	})

	t.Run("reads top-level url", func(t *testing.T) {
		body := []byte(`{"url":"https://example.test/top.flac"}`)

		got, err := extractQobuzDownloadURLFromBody(body)
		if err != nil {
			t.Fatalf("expected no error, got %v", err)
		}
		if got != "https://example.test/top.flac" {
			t.Fatalf("unexpected URL: %q", got)
		}
	})

	t.Run("returns API error", func(t *testing.T) {
		body := []byte(`{"error":"track not found"}`)

		_, err := extractQobuzDownloadURLFromBody(body)
		if err == nil || err.Error() != "track not found" {
			t.Fatalf("expected track-not-found error, got %v", err)
		}
	})

	t.Run("returns message when success false", func(t *testing.T) {
		body := []byte(`{"success":false,"message":"blocked"}`)

		_, err := extractQobuzDownloadURLFromBody(body)
		if err == nil || err.Error() != "blocked" {
			t.Fatalf("expected blocked error, got %v", err)
		}
	})

	t.Run("returns detail error", func(t *testing.T) {
		body := []byte(`{"detail":"Invalid quality 'lossless'. Choose from: ['mp3', 'cd', 'hi-res', 'hi-res-max']"}`)

		_, err := extractQobuzDownloadURLFromBody(body)
		if err == nil || err.Error() != "Invalid quality 'lossless'. Choose from: ['mp3', 'cd', 'hi-res', 'hi-res-max']" {
			t.Fatalf("expected detail error, got %v", err)
		}
	})
}

func TestNormalizeQobuzQualityCode(t *testing.T) {
	tests := map[string]string{
		"":           "6",
		"5":          "6",
		"6":          "6",
		"cd":         "6",
		"lossless":   "6",
		"7":          "7",
		"hi-res":     "7",
		"27":         "27",
		"hi-res-max": "27",
		"unexpected": "6",
	}

	for input, want := range tests {
		if got := normalizeQobuzQualityCode(input); got != want {
			t.Fatalf("normalizeQobuzQualityCode(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestGetQobuzDebugKey(t *testing.T) {
	got := getQobuzDebugKey()
	if len(got) != len(qobuzDebugKeyObfuscated) {
		t.Fatalf("unexpected debug key length: %d", len(got))
	}
	for i := range got {
		if got[i]^qobuzDebugKeyXORMask != qobuzDebugKeyObfuscated[i] {
			t.Fatalf("unexpected debug key reconstruction at index %d", i)
		}
	}
}

func TestQobuzAvailableProviders(t *testing.T) {
	providers := NewQobuzDownloader().GetAvailableProviders()
	if len(providers) != 3 {
		t.Fatalf("expected 3 Qobuz providers, got %d", len(providers))
	}

	want := map[string]string{
		"musicdl":  qobuzAPIKindMusicDL,
		"dabmusic": qobuzAPIKindStandard,
		"deeb":     qobuzAPIKindStandard,
	}

	for _, provider := range providers {
		wantKind, ok := want[provider.Name]
		if !ok {
			t.Fatalf("unexpected provider %q", provider.Name)
		}
		if provider.Kind != wantKind {
			t.Fatalf("provider %q has kind %q, want %q", provider.Name, provider.Kind, wantKind)
		}
		delete(want, provider.Name)
	}

	if len(want) != 0 {
		t.Fatalf("missing providers: %v", want)
	}
}
