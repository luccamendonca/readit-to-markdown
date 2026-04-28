# content-conversion Specification

## Purpose

Define how `readit` fetches the URL and converts the response into a Markdown body plus frontmatter metadata. Three dispatch modes — HTML, Markdown, Plain — plus a stub fallback — produce a consistent on-disk shape regardless of upstream content type.

## Requirements

### Requirement: HTTP fetch is bounded and identifiable

`readit` SHALL perform a single HTTP GET against the URL with a 30-second timeout, an explicit `User-Agent` of `readit/1.0 (+https://github.com/luccacm/readit)`, and an `Accept` header of `text/markdown, text/html;q=0.9, text/plain;q=0.8, */*;q=0.5`. The response body SHALL be capped at 20 MiB.

#### Scenario: Fetch follows redirects and records final URL
- **WHEN** the URL responds with `301`/`302`/`307`/`308`
- **THEN** the Go default client SHALL follow up to 10 redirects
- **AND** the URL passed to readability for parsing SHALL be the final post-redirect URL

#### Scenario: Non-2xx status triggers stub fallback
- **WHEN** the HTTP response status is outside `[200, 299]`
- **THEN** `readit` SHALL print `fetch fail (http <status>), saving stub` to stderr
- **AND** SHALL produce a stub output (see "Stub fallback" requirement)

#### Scenario: Network error triggers stub fallback
- **WHEN** DNS lookup fails, connection refused, TLS error, or any I/O error during fetch
- **THEN** `readit` SHALL print `fetch fail (<err>), saving stub` to stderr
- **AND** SHALL produce a stub output

#### Scenario: Body cap prevents runaway downloads
- **WHEN** the upstream response body exceeds 20 MiB
- **THEN** `readit` SHALL read at most 20 MiB and stop, treating the truncated body as the full input
- **AND** MUST NOT panic, hang, or exit non-zero solely because of truncation

### Requirement: Dispatch is decided by Content-Type and URL extension

After a successful fetch, `readit` SHALL classify the response into exactly one of four modes by inspecting the response `Content-Type` media type (case-insensitive, parameters stripped) and the URL path's lowercase extension.

The four modes are: `html`, `markdown`, `plain`, `other`.

#### Scenario: Markdown mode triggers on text/markdown
- **WHEN** the media type equals `text/markdown` OR `text/x-markdown`
- **THEN** the dispatch mode SHALL be `markdown`

#### Scenario: Markdown mode triggers on .md extension
- **WHEN** the URL path ends in `.md` or `.markdown` (case-insensitive)
- **THEN** the dispatch mode SHALL be `markdown` regardless of media type

#### Scenario: Plain mode triggers on text/plain or .txt
- **WHEN** the media type equals `text/plain` OR the URL path ends in `.txt`
- **AND** the URL is not already classified as `markdown`
- **THEN** the dispatch mode SHALL be `plain`

#### Scenario: HTML mode is the default for web pages
- **WHEN** the media type is `text/html`, `application/xhtml+xml`, or empty
- **AND** no markdown/plain rule has matched
- **THEN** the dispatch mode SHALL be `html`

#### Scenario: Unknown media types fall back to stub
- **WHEN** the media type is anything else (e.g. `application/pdf`, `image/png`, `application/json`)
- **THEN** the dispatch mode SHALL be `other`
- **AND** `readit` SHALL print `unsupported content-type "<type>", saving stub` to stderr

### Requirement: HTML mode extracts a readable article

In `html` mode, `readit` SHALL invoke a Readability-style extractor (currently `go-shiori/go-readability`) on the fetched HTML, using the post-redirect URL as the document URL.

#### Scenario: Successful extraction produces title, summary, date, body
- **WHEN** readability returns a non-empty `TextContent`
- **THEN** `title` SHALL be the trimmed `Title` (falling back to the URL slug if empty)
- **AND** `summary` SHALL be the trimmed `Excerpt`
- **AND** `date` SHALL be `PublishedTime` formatted as `YYYY-MM-DD` (or empty if absent)
- **AND** the article HTML SHALL be converted to Markdown via `JohannesKaufmann/html-to-markdown` v2 with the `base` and `commonmark` plugins enabled
- **AND** the converted Markdown SHALL be the file body

#### Scenario: Empty extraction falls back to stub body
- **WHEN** readability returns empty `TextContent` OR returns an error
- **THEN** `readit` SHALL print `parse fail (<err>), saving stub` to stderr
- **AND** SHALL emit a stub body (URL only) but SHALL still attempt to derive `title` from the URL slug

#### Scenario: html-to-markdown conversion failure falls back to URL body
- **WHEN** readability succeeded but the HTML→Markdown conversion errors or returns whitespace-only output
- **THEN** the body SHALL be the URL string
- **AND** `title`, `summary`, `date` SHALL still come from the readability extraction

### Requirement: Markdown mode preserves the body verbatim

In `markdown` mode, `readit` SHALL save the response body byte-for-byte as the file body, with no parsing, no rewriting of links or images, and no readability invocation.

#### Scenario: Title comes from the first H1
- **WHEN** the response body contains a line matching `^#\s+(.*)`
- **THEN** the trimmed text after `# ` of the first such line SHALL be `title`

#### Scenario: Title falls back to URL slug if no H1
- **WHEN** the response body has no `# H1` line
- **THEN** `title` SHALL be the last path segment of the URL with extension stripped, falling back to host

#### Scenario: Summary and date are empty
- **WHEN** dispatch mode is `markdown`
- **THEN** `summary` SHALL be empty
- **AND** `date` SHALL be empty (rendered as `null`)

### Requirement: Plain mode preserves the body verbatim

In `plain` mode, `readit` SHALL save the response body byte-for-byte. Tabs, indentation, and line breaks MUST be preserved.

#### Scenario: Title comes from URL slug
- **WHEN** dispatch mode is `plain`
- **THEN** `title` SHALL be the last path segment of the URL with extension stripped, falling back to host
- **AND** `summary` and `date` SHALL be empty

### Requirement: Stub fallback produces a minimal but well-formed file

When dispatch is `other`, fetch fails, or no body can be extracted, `readit` SHALL still produce a well-formed Markdown file containing valid frontmatter and the URL as the body.

#### Scenario: Stub file body equals the URL
- **WHEN** stub fallback is taken
- **THEN** the file body SHALL be exactly the input URL followed by a newline
- **AND** frontmatter SHALL contain `title` (derived from URL host + path), empty `summary`, `null` date, and `url`
- **AND** the file SHALL still be written under the same `YYYY-MM-DD_<slug>.md` naming as a successful run

### Requirement: Frontmatter shape is fixed and Obsidian-compatible

Every output file SHALL begin with a YAML frontmatter block delimited by `---` lines, containing exactly the fields `title`, `summary`, `date`, `url`, `read_time`, in that order. Other fields (`authors`, `topics`, `type`, etc.) MUST NOT be emitted.

#### Scenario: Field order and presence
- **WHEN** any output file is written (success, partial, or stub)
- **THEN** the first line SHALL be `---`
- **AND** subsequent lines SHALL be `title: "<value>"`, `summary: "<value>"`, `date: <value-or-null>`, `url: <value>`, `read_time: <value>`
- **AND** the closing `---` SHALL be followed by the body

#### Scenario: Date is null when unknown
- **WHEN** no published date can be extracted (markdown mode, plain mode, html mode without date metadata, or stub fallback)
- **THEN** the `date` line SHALL be exactly `date: null`

#### Scenario: Strings are escaped for YAML safety
- **WHEN** `title` or `summary` contains `"`, `\`, or a newline
- **THEN** `\` SHALL be escaped to `\\`, `"` SHALL be escaped to `\"`, and newlines SHALL be replaced with a single space

### Requirement: Read time is estimated from the body word count

Every output file SHALL include a `read_time` field in the frontmatter representing the estimated reading time in whole minutes. The estimate SHALL be computed from the final file body (the same Markdown that follows the frontmatter) using a fixed 200 words-per-minute baseline.

The word count SHALL be the number of whitespace-separated tokens in the body (`strings.Fields` semantics). The reading time SHALL be `ceil(words / 200)`, except that an empty or whitespace-only body SHALL yield `0`.

#### Scenario: Read time rounds up to the nearest minute
- **WHEN** the body contains 201 whitespace-separated words
- **THEN** `read_time` SHALL be `2`

#### Scenario: Empty body yields zero
- **WHEN** the body is empty or contains only whitespace
- **THEN** `read_time` SHALL be `0`

#### Scenario: Read time is emitted as an integer
- **WHEN** any output file is written
- **THEN** the frontmatter SHALL contain a line of the form `read_time: <N>` where `<N>` is a non-negative integer (no quotes, no unit suffix)
