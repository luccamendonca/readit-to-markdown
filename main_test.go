package main

import (
	"strings"
	"testing"
)

func TestReadTimeMinutes(t *testing.T) {
	tests := []struct {
		name string
		body string
		want int
	}{
		{"empty", "", 0},
		{"whitespace only", "   \n\t  ", 0},
		{"single word", "hello", 1},
		{"under one minute", strings.Repeat("word ", 50), 1},
		{"exactly 200 words", strings.Repeat("word ", 200), 1},
		{"201 words rounds up", strings.Repeat("word ", 201), 2},
		{"1000 words", strings.Repeat("word ", 1000), 5},
		{"1001 words rounds up", strings.Repeat("word ", 1001), 6},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := readTimeMinutes(tt.body); got != tt.want {
				t.Errorf("readTimeMinutes() = %d, want %d", got, tt.want)
			}
		})
	}
}

func TestBuildFileIncludesReadTime(t *testing.T) {
	out := buildFile("Title", "summary", "2026-04-28", "https://example.com", 7, "body text\n")
	if !strings.Contains(out, "read_time: 7\n") {
		t.Errorf("expected frontmatter to contain 'read_time: 7', got:\n%s", out)
	}
	urlIdx := strings.Index(out, "url:")
	rtIdx := strings.Index(out, "read_time:")
	if urlIdx < 0 || rtIdx < 0 || rtIdx < urlIdx {
		t.Errorf("expected read_time after url in frontmatter, got:\n%s", out)
	}
}
