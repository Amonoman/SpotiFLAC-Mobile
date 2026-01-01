package gobackend

import (
	"fmt"
	"regexp"
	"strings"
)

// Invalid filename characters for Android/Windows/Linux
var invalidChars = regexp.MustCompile(`[<>:"/\\|?*\x00-\x1f]`)

// sanitizeFilename removes invalid characters from filename
func sanitizeFilename(filename string) string {
	// Replace invalid characters with underscore
	sanitized := invalidChars.ReplaceAllString(filename, "_")
	
	// Remove leading/trailing spaces and dots
	sanitized = strings.TrimSpace(sanitized)
	sanitized = strings.Trim(sanitized, ".")
	
	// Collapse multiple underscores
	multiUnderscore := regexp.MustCompile(`_+`)
	sanitized = multiUnderscore.ReplaceAllString(sanitized, "_")
	
	// Limit length (Android has 255 byte limit for filenames)
	if len(sanitized) > 200 {
		sanitized = sanitized[:200]
	}
	
	// Ensure not empty
	if sanitized == "" {
		sanitized = "untitled"
	}
	
	return sanitized
}

// buildFilenameFromTemplate builds a filename from template and metadata
func buildFilenameFromTemplate(template string, metadata map[string]interface{}) string {
	if template == "" {
		template = "{artist} - {title}"
	}
	
	result := template
	
	// Replace placeholders
	placeholders := map[string]string{
		"{title}":  getString(metadata, "title"),
		"{artist}": getString(metadata, "artist"),
		"{album}":  getString(metadata, "album"),
		"{track}":  formatTrackNumber(getInt(metadata, "track")),
		"{year}":   getString(metadata, "year"),
		"{disc}":   formatDiscNumber(getInt(metadata, "disc")),
	}
	
	for placeholder, value := range placeholders {
		result = strings.ReplaceAll(result, placeholder, value)
	}
	
	return result
}

func getString(m map[string]interface{}, key string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok {
			// Trim leading/trailing whitespace to prevent filename issues
			return strings.TrimSpace(s)
		}
	}
	return ""
}

func getInt(m map[string]interface{}, key string) int {
	if v, ok := m[key]; ok {
		switch n := v.(type) {
		case int:
			return n
		case int64:
			return int(n)
		case float64:
			return int(n)
		}
	}
	return 0
}

func formatTrackNumber(n int) string {
	if n <= 0 {
		return ""
	}
	return fmt.Sprintf("%02d", n)
}

func formatDiscNumber(n int) string {
	if n <= 0 {
		return ""
	}
	return fmt.Sprintf("%d", n)
}

// extractYear extracts year from date string (YYYY-MM-DD or YYYY)
func extractYear(date string) string {
	if len(date) >= 4 {
		return date[:4]
	}
	return date
}
