package gobackend

import (
	"io"
	"net/http"
	"strings"
	"testing"
)

type roundTripFunc func(*http.Request) (*http.Response, error)

func (fn roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return fn(req)
}

func TestGetRetryAfterDurationMissingHeaderReturnsZero(t *testing.T) {
	resp := &http.Response{
		Header: make(http.Header),
	}

	if got := getRetryAfterDuration(resp); got != 0 {
		t.Fatalf("getRetryAfterDuration() = %v, want 0", got)
	}
}

func TestCheckTrackAvailabilityFromSpotifyViaResolveAPI(t *testing.T) {
	origRetryConfig := songLinkRetryConfig
	defer func() { songLinkRetryConfig = origRetryConfig }()

	client := &SongLinkClient{
		client: &http.Client{
			Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
				if req.URL.Host == "api.zarz.moe" && req.URL.Path == "/v1/resolve" && req.Method == "POST" {
					body := `{"success":true,"isrc":"USRC12345678","songUrls":{"Spotify":"https://open.spotify.com/track/testspotifyid","Deezer":"https://www.deezer.com/track/908604612","AmazonMusic":"https://music.amazon.com/albums/B086Q2QNLH?trackAsin=B086Q41M9C","Tidal":"https://listen.tidal.com/track/134858527","Qobuz":"https://open.qobuz.com/track/195125822","YouTubeMusic":"https://music.youtube.com/watch?v=testvideoid1"}}`
					return &http.Response{
						StatusCode: 200,
						Header:     make(http.Header),
						Body:       io.NopCloser(strings.NewReader(body)),
						Request:    req,
					}, nil
				}
				t.Fatalf("unexpected request: %s %s", req.Method, req.URL.String())
				return nil, nil
			}),
		},
	}

	availability, err := client.CheckTrackAvailability("testspotifyid", "")
	if err != nil {
		t.Fatalf("CheckTrackAvailability() error = %v", err)
	}

	if availability.SpotifyID != "testspotifyid" {
		t.Fatalf("SpotifyID = %q, want %q", availability.SpotifyID, "testspotifyid")
	}
	if !availability.Deezer || availability.DeezerID != "908604612" {
		t.Fatalf("Deezer availability = %+v, want DeezerID 908604612", availability)
	}
	if !availability.Amazon || !availability.Tidal || !availability.Qobuz || !availability.YouTube {
		t.Fatalf("availability flags = %+v, want Amazon/Tidal/Qobuz/YouTube true", availability)
	}
	if availability.YouTubeID != "testvideoid1" {
		t.Fatalf("YouTubeID = %q, want %q", availability.YouTubeID, "testvideoid1")
	}
}

func TestCheckTrackAvailabilityFromSpotifyResolveAPIFailure(t *testing.T) {
	origRetryConfig := songLinkRetryConfig
	songLinkRetryConfig = func() RetryConfig {
		return RetryConfig{MaxRetries: 0, InitialDelay: 0, MaxDelay: 0, BackoffFactor: 1}
	}
	defer func() { songLinkRetryConfig = origRetryConfig }()

	var hitSongLink bool

	client := &SongLinkClient{
		client: &http.Client{
			Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
				// Resolve proxy returns 500
				if req.URL.Host == "api.zarz.moe" && req.URL.Path == "/v1/resolve" {
					return &http.Response{
						StatusCode: 500,
						Header:     make(http.Header),
						Body:       io.NopCloser(strings.NewReader("internal error")),
						Request:    req,
					}, nil
				}
				// SongLink fallback should be called
				if req.URL.Host == "api.song.link" {
					hitSongLink = true
					body := `{"linksByPlatform":{"spotify":{"url":"https://open.spotify.com/track/testspotifyid"},"deezer":{"url":"https://www.deezer.com/track/908604612"},"tidal":{"url":"https://listen.tidal.com/track/134858527"}}}`
					return &http.Response{
						StatusCode: 200,
						Header:     make(http.Header),
						Body:       io.NopCloser(strings.NewReader(body)),
						Request:    req,
					}, nil
				}
				t.Fatalf("unexpected request: %s %s", req.Method, req.URL.String())
				return nil, nil
			}),
		},
	}

	availability, err := client.CheckTrackAvailability("testspotifyid", "")
	if err != nil {
		t.Fatalf("expected SongLink fallback to succeed, got error: %v", err)
	}
	if !hitSongLink {
		t.Fatal("expected fallback request to SongLink API, but it was never called")
	}
	if !availability.Deezer || availability.DeezerID != "908604612" {
		t.Fatalf("Deezer availability via fallback = %+v, want DeezerID 908604612", availability)
	}
}

func TestCheckAvailabilityFromDeezerUsesSongLink(t *testing.T) {
	origRetryConfig := songLinkRetryConfig
	songLinkRetryConfig = func() RetryConfig {
		return RetryConfig{MaxRetries: 0, InitialDelay: 0, MaxDelay: 0, BackoffFactor: 1}
	}
	defer func() { songLinkRetryConfig = origRetryConfig }()

	client := &SongLinkClient{
		client: &http.Client{
			Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
				// Non-Spotify should go to SongLink, not resolve API
				if req.URL.Host == "api.zarz.moe" {
					t.Fatalf("non-Spotify URL should not hit resolve API, got: %s", req.URL.String())
					return nil, nil
				}
				if req.URL.Host == "api.song.link" {
					body := `{"linksByPlatform":{"spotify":{"url":"https://open.spotify.com/track/testid"},"deezer":{"url":"https://www.deezer.com/track/908604612"},"tidal":{"url":"https://listen.tidal.com/track/134858527"},"qobuz":{"url":"https://open.qobuz.com/track/195125822"},"youtubeMusic":{"url":"https://music.youtube.com/watch?v=testvid"}}}`
					return &http.Response{
						StatusCode: 200,
						Header:     make(http.Header),
						Body:       io.NopCloser(strings.NewReader(body)),
						Request:    req,
					}, nil
				}
				t.Fatalf("unexpected request: %s %s", req.Method, req.URL.String())
				return nil, nil
			}),
		},
	}

	availability, err := client.checkAvailabilityFromDeezerSongLink("908604612")
	if err != nil {
		t.Fatalf("checkAvailabilityFromDeezerSongLink() error = %v", err)
	}

	if !availability.Deezer || availability.DeezerID != "908604612" {
		t.Fatalf("Deezer = %+v, want DeezerID 908604612", availability)
	}
	if availability.SpotifyID != "testid" {
		t.Fatalf("SpotifyID = %q, want %q", availability.SpotifyID, "testid")
	}
}
