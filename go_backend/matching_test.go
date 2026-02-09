package gobackend

import "testing"

func TestQobuzTitlesMatchCrossScript(t *testing.T) {
	t.Run("rejects unrelated cross-script titles", func(t *testing.T) {
		if qobuzTitlesMatch("パンツ脱げるもん！", "Warrior of the Darkness") {
			t.Fatalf("expected unrelated cross-script titles to not match")
		}
	})

	t.Run("accepts transliterated japanese title", func(t *testing.T) {
		if !qobuzTitlesMatch("パンツ脱げるもん！", "Pantsu Nugeru Mon") {
			t.Fatalf("expected transliterated japanese title to match")
		}
	})
}

func TestQobuzArtistsMatchCrossScript(t *testing.T) {
	t.Run("rejects unrelated cross-script artists", func(t *testing.T) {
		if qobuzArtistsMatch("TakeponG", "陳奕迅") {
			t.Fatalf("expected unrelated cross-script artists to not match")
		}
	})

	t.Run("accepts transliterated japanese artist", func(t *testing.T) {
		if !qobuzArtistsMatch("たけぽんぐ", "takepong") {
			t.Fatalf("expected transliterated japanese artist to match")
		}
	})
}

func TestTidalTitlesMatchCrossScript(t *testing.T) {
	t.Run("rejects unrelated cross-script titles", func(t *testing.T) {
		if titlesMatch("パンツ脱げるもん！", "Warrior of the Darkness") {
			t.Fatalf("expected unrelated cross-script titles to not match")
		}
	})

	t.Run("accepts transliterated japanese title", func(t *testing.T) {
		if !titlesMatch("パンツ脱げるもん！", "Pantsu Nugeru Mon") {
			t.Fatalf("expected transliterated japanese title to match")
		}
	})
}

func TestTidalArtistsMatchCrossScript(t *testing.T) {
	t.Run("rejects unrelated cross-script artists", func(t *testing.T) {
		if artistsMatch("TakeponG", "陳奕迅") {
			t.Fatalf("expected unrelated cross-script artists to not match")
		}
	})

	t.Run("accepts transliterated japanese artist", func(t *testing.T) {
		if !artistsMatch("たけぽんぐ", "takepong") {
			t.Fatalf("expected transliterated japanese artist to match")
		}
	})
}
