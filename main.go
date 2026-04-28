package main

import (
	"flag"
	"fmt"
	"io"
	"mime"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/JohannesKaufmann/html-to-markdown/v2/converter"
	"github.com/JohannesKaufmann/html-to-markdown/v2/plugin/base"
	mdplugin "github.com/JohannesKaufmann/html-to-markdown/v2/plugin/commonmark"
	"github.com/atotto/clipboard"
	"github.com/gen2brain/beeep"
	readability "github.com/go-shiori/go-readability"
)

const userAgent = "readit/1.0 (+https://github.com/luccamendonca/readit-to-markdown)"

func main() {
	var dirFlag string
	var urlFlag string
	var quiet bool
	flag.StringVar(&dirFlag, "dir", "", "output directory (overrides $READIT_DIR)")
	flag.StringVar(&urlFlag, "url", "", "URL to fetch (overrides clipboard; positional arg also accepted)")
	flag.BoolVar(&quiet, "quiet", false, "suppress desktop notifications")
	flag.Parse()

	notify := !quiet && os.Getenv("READIT_NOTIFY") != "0"

	outDir := resolveDir(dirFlag)
	if outDir == "" {
		fatal(notify, "no output dir: pass --dir or set $READIT_DIR")
	}
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		fatal(notify, "mkdir %s: %v", outDir, err)
	}

	raw, source := resolveInput(urlFlag, flag.Args())
	if source == "clipboard" {
		clip, err := clipboard.ReadAll()
		if err != nil {
			fatal(notify, "clipboard read: %v", err)
		}
		raw = clip
	}
	raw = strings.TrimSpace(raw)

	u, ok := parseURL(raw)
	if !ok {
		switch source {
		case "clipboard":
			fmt.Fprintln(os.Stderr, "clipboard not URL, exit")
			os.Exit(0)
		default:
			fatal(notify, "%s not a valid http(s) URL: %q", source, raw)
		}
	}

	fmt.Fprintf(os.Stderr, "fetching %s\n", u.String())

	title, summary, date, body := process(u)

	fname := buildFilename(title, time.Now())
	out := filepath.Join(outDir, fname)

	readTime := readTimeMinutes(body)
	content := buildFile(title, summary, date, u.String(), readTime, body)
	if err := os.WriteFile(out, []byte(content), 0o644); err != nil {
		fatal(notify, "write %s: %v", out, err)
	}
	fmt.Println(out)

	if notify {
		_ = beeep.Notify("readit ✓ saved", title+"\n"+filepath.Base(out), "")
	}
}

func process(u *url.URL) (title, summary, date, body string) {
	bodyBytes, ctype, finalURL, err := fetch(u.String())
	if err != nil {
		fmt.Fprintf(os.Stderr, "fetch fail (%v), saving stub\n", err)
		return u.Host + u.Path, "", "", u.String()
	}

	mediaType, _, _ := mime.ParseMediaType(ctype)
	mediaType = strings.ToLower(mediaType)
	urlPath := strings.ToLower(u.Path)

	switch {
	case mediaType == "text/markdown" || mediaType == "text/x-markdown" || strings.HasSuffix(urlPath, ".md") || strings.HasSuffix(urlPath, ".markdown"):
		return processMarkdown(u, bodyBytes)
	case mediaType == "text/plain" || strings.HasSuffix(urlPath, ".txt"):
		return processPlain(u, bodyBytes)
	case mediaType == "text/html" || mediaType == "application/xhtml+xml" || mediaType == "":
		return processHTML(u, bodyBytes, finalURL)
	default:
		fmt.Fprintf(os.Stderr, "unsupported content-type %q, saving stub\n", mediaType)
		return u.Host + u.Path, "", "", u.String()
	}
}

func processMarkdown(u *url.URL, body []byte) (string, string, string, string) {
	text := string(body)
	title := firstMarkdownHeading(text)
	if title == "" {
		title = titleFromURL(u)
	}
	return title, "", "", text
}

func processPlain(u *url.URL, body []byte) (string, string, string, string) {
	return titleFromURL(u), "", "", string(body)
}

func processHTML(u *url.URL, body []byte, finalURL *url.URL) (string, string, string, string) {
	parsedURL := finalURL
	if parsedURL == nil {
		parsedURL = u
	}
	article, err := readability.FromReader(strings.NewReader(string(body)), parsedURL)
	if err != nil || strings.TrimSpace(article.TextContent) == "" {
		fmt.Fprintf(os.Stderr, "parse fail (%v), saving stub\n", err)
		return titleFromURL(u), "", "", u.String()
	}
	title := strings.TrimSpace(article.Title)
	if title == "" {
		title = titleFromURL(u)
	}
	summary := strings.TrimSpace(article.Excerpt)
	date := ""
	if article.PublishedTime != nil && !article.PublishedTime.IsZero() {
		date = article.PublishedTime.Format("2006-01-02")
	}
	md, mdErr := htmlToMarkdown(article.Content)
	if mdErr != nil || strings.TrimSpace(md) == "" {
		return title, summary, date, u.String()
	}
	return title, summary, date, md
}

func fetch(rawURL string) ([]byte, string, *url.URL, error) {
	client := &http.Client{Timeout: 30 * time.Second}
	req, err := http.NewRequest(http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, "", nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "text/markdown, text/html;q=0.9, text/plain;q=0.8, */*;q=0.5")
	resp, err := client.Do(req)
	if err != nil {
		return nil, "", nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, "", nil, fmt.Errorf("http %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 20<<20))
	if err != nil {
		return nil, "", nil, err
	}
	return body, resp.Header.Get("Content-Type"), resp.Request.URL, nil
}

func firstMarkdownHeading(s string) string {
	for _, line := range strings.Split(s, "\n") {
		l := strings.TrimSpace(line)
		if strings.HasPrefix(l, "# ") {
			return strings.TrimSpace(strings.TrimPrefix(l, "# "))
		}
	}
	return ""
}

func titleFromURL(u *url.URL) string {
	base := path.Base(u.Path)
	base = strings.TrimSuffix(base, filepath.Ext(base))
	if base == "" || base == "." || base == "/" {
		return u.Host
	}
	return base
}

// resolveInput picks the URL source by precedence:
//  1. --url flag
//  2. first positional arg
//  3. clipboard (deferred — caller reads it)
//
// Returns the raw input (empty for clipboard, since we defer that read so
// "no flag, no arg, no clipboard read needed" stays a single code path) and
// a label for diagnostics: "flag", "arg", or "clipboard".
func resolveInput(urlFlag string, args []string) (string, string) {
	if urlFlag != "" {
		return urlFlag, "flag"
	}
	if len(args) > 0 && args[0] != "" {
		return args[0], "arg"
	}
	return "", "clipboard"
}

func resolveDir(flagVal string) string {
	if flagVal != "" {
		return expand(flagVal)
	}
	return expand(os.Getenv("READIT_DIR"))
}

func expand(p string) string {
	p = unescapeShell(p)
	if strings.HasPrefix(p, "~/") {
		home, err := os.UserHomeDir()
		if err == nil {
			return filepath.Join(home, p[2:])
		}
	}
	return p
}

// unescapeShell strips leaked shell-escape backslashes from a path
// (e.g. "Mobile\\ Documents" -> "Mobile Documents"). Common when
// $READIT_DIR was set with single quotes preserving backslashes.
func unescapeShell(p string) string {
	if !strings.Contains(p, `\`) {
		return p
	}
	var b strings.Builder
	b.Grow(len(p))
	for i := 0; i < len(p); i++ {
		if p[i] == '\\' && i+1 < len(p) {
			next := p[i+1]
			if next == ' ' || next == '\t' || next == '\\' {
				b.WriteByte(next)
				i++
				continue
			}
		}
		b.WriteByte(p[i])
	}
	return b.String()
}

func parseURL(s string) (*url.URL, bool) {
	if s == "" {
		return nil, false
	}
	u, err := url.Parse(s)
	if err != nil || u.Scheme == "" || u.Host == "" {
		return nil, false
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return nil, false
	}
	return u, true
}

func htmlToMarkdown(html string) (string, error) {
	conv := converter.NewConverter(
		converter.WithPlugins(
			base.NewBasePlugin(),
			mdplugin.NewCommonmarkPlugin(),
		),
	)
	return conv.ConvertString(html)
}

var slugRe = regexp.MustCompile(`[^a-z0-9]+`)

func slugify(s string) string {
	s = strings.ToLower(s)
	s = slugRe.ReplaceAllString(s, "-")
	s = strings.Trim(s, "-")
	if len(s) > 80 {
		s = s[:80]
		s = strings.Trim(s, "-")
	}
	return s
}

func buildFilename(title string, now time.Time) string {
	slug := slugify(title)
	if slug == "" {
		slug = "untitled"
	}
	return fmt.Sprintf("%s_%s.md", now.Format("2006-01-02"), slug)
}

func yamlEscape(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `"`, `\"`)
	s = strings.ReplaceAll(s, "\n", " ")
	return s
}

func buildFile(title, summary, date, urlStr string, readTime int, body string) string {
	var b strings.Builder
	b.WriteString("---\n")
	fmt.Fprintf(&b, "title: \"%s\"\n", yamlEscape(title))
	if summary != "" {
		fmt.Fprintf(&b, "summary: \"%s\"\n", yamlEscape(summary))
	} else {
		b.WriteString("summary: \"\"\n")
	}
	if date != "" {
		fmt.Fprintf(&b, "date: %s\n", date)
	} else {
		b.WriteString("date: null\n")
	}
	fmt.Fprintf(&b, "url: %s\n", urlStr)
	fmt.Fprintf(&b, "read_time: %d\n", readTime)
	b.WriteString("---\n")
	b.WriteString(body)
	if !strings.HasSuffix(body, "\n") {
		b.WriteString("\n")
	}
	return b.String()
}

// readTimeMinutes estimates reading time in minutes for the given body
// using a 200 words-per-minute baseline (a common conservative average).
// Returns 0 when body has no words, otherwise rounds up to the nearest minute.
func readTimeMinutes(body string) int {
	words := len(strings.Fields(body))
	if words == 0 {
		return 0
	}
	const wpm = 200
	minutes := words / wpm
	if words%wpm != 0 {
		minutes++
	}
	return minutes
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "error: "+format+"\n", args...)
	os.Exit(1)
}

func fatal(notify bool, format string, args ...any) {
	msg := fmt.Sprintf(format, args...)
	fmt.Fprintln(os.Stderr, "error: "+msg)
	if notify {
		_ = beeep.Alert("readit ✗ error", msg, "")
	}
	os.Exit(1)
}
