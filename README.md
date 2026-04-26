# readit

A tiny CLI that turns whatever URL is on your clipboard into an Obsidian-friendly markdown file in a folder you choose.

Built for the "save it now, read it later" workflow: copy a link, run `readit`, get a clean `.md` file in your read-later inbox with title, summary, date, and source URL captured as YAML frontmatter.

## What it does

1. Resolves a URL from `--url` flag, positional arg, or system clipboard (in that priority)
2. If clipboard fallback is taken and clipboard is **not** a URL → exits silently
3. If a URL is resolved → fetches it and inspects `Content-Type`:
   - **HTML** → extracts main article via [go-readability](https://github.com/go-shiori/go-readability) and converts to Markdown via [html-to-markdown v2](https://github.com/JohannesKaufmann/html-to-markdown)
   - **Markdown** (`text/markdown`, `*.md`) → saves the body verbatim
   - **Plain text** (`text/plain`, `*.txt`) → saves the body verbatim
   - **Other / unreachable / parse fail** → saves a stub file containing only the URL
4. Writes `<dir>/YYYY-MM-DD_<slug>.md` with frontmatter
5. Fires a desktop notification (`readit ✓ saved` or `readit ✗ error`)

## Install

```sh
go install github.com/luccamendonca/readit-to-markdown@latest
```

Binary lands at `$(go env GOPATH)/bin/readit-to-markdown`. Symlink or alias it to `readit` if you want the shorter name:

```sh
ln -s "$(go env GOPATH)/bin/readit-to-markdown" "$(go env GOPATH)/bin/readit"
# or
alias readit=readit-to-markdown
```

To build from source with the short name directly:

```sh
git clone https://github.com/luccamendonca/readit-to-markdown
cd readit-to-markdown
go build -o readit .
mv readit "$(go env GOPATH)/bin/"
```

## Configure

Output directory comes from (in order):

1. `--dir <path>` flag
2. `READIT_DIR` env var

```sh
# ~/.zshrc — pick one quoting style
export READIT_DIR=~/Documents/Obsidian/ReadItLater\ Inbox          # unquoted, shell escapes spaces
export READIT_DIR="$HOME/Documents/Obsidian/ReadItLater Inbox"    # double-quoted, no escape
```

> **Don't** wrap in single quotes with backslashes — `'~/foo\ bar'` keeps the backslash literal. (`readit` tolerates it now, but the cleaner form is above.)

The directory is created if missing.

## Usage

```sh
readit                                  # reads URL from clipboard
readit https://example.com/article      # positional URL
readit --url https://example.com/x      # explicit flag
readit --dir ~/Notes/inbox              # override output dir
readit --quiet                          # no desktop notification
READIT_NOTIFY=0 readit                  # same, via env
```

URL is resolved in this priority: **`--url` flag** → **positional arg** → **clipboard**. The first non-empty source wins; lower-priority sources aren't consulted.

Behavior on invalid input differs by source:

- **Clipboard** with no URL → silent no-op, exit `0` (so a bare `readit` bound to a hotkey is harmless).
- **`--url` / positional** with a non-`http(s)` value → loud error, exit `1`, error notification.

Prints the absolute path of the written file to stdout. Errors go to stderr and trigger an alert notification (unless `--quiet`).

## Output format

```yaml
---
title: "The article's title"
summary: "First paragraph or meta description"
date: 2026-02-09       # or null if not detected
url: https://...
---

# The article's title

Full article body as Markdown...
```

Compatible with Obsidian properties and most static-site frontmatter parsers.

## File naming

`YYYY-MM-DD_<slug>.md`, where:

- `YYYY-MM-DD` = today's local date (when `readit` was run)
- `<slug>` = lowercase title, non-alphanumeric runs collapsed to `-`, trimmed to 80 chars

If the title can't be derived, slug falls back to the last segment of the URL path, then the host. If everything fails, slug is `untitled`.

## Frontmatter fields

| Field     | Source                                                       |
|-----------|--------------------------------------------------------------|
| `title`   | `<title>` / `og:title` / first H1 / URL slug                 |
| `summary` | `<meta name="description">` / `og:description` (HTML only)   |
| `date`    | `og:article:published_time` / JSON-LD; `null` if absent      |
| `url`     | the URL from your clipboard                                  |

`authors`, `topics`, `type` are intentionally omitted — they aren't reliably extractable.

## Notifications

Cross-platform via [beeep](https://github.com/gen2brain/beeep):

- **macOS** → `osascript display notification`
- **Linux** → `notify-send` (libnotify)
- **Windows** → native toast

Disable with `--quiet` or `READIT_NOTIFY=0`.

## Limits & known gotchas

- **SPA / client-rendered pages** (e.g. Stripe blog) → readability sees only the static HTML shell, so the captured body may be sparse. Acceptable per the "save what we got" model.
- **Login-walled / paywalled pages** → typically fall back to stub.
- **Body cap** = 20 MB (hard limit on fetched response).
- **Timeout** = 30 s.

## Layout

```
.
├── main.go              # everything lives here, ~250 LOC
├── go.mod / go.sum
├── README.md            # this file
└── openspec/
    ├── project.md
    └── specs/
        ├── clipboard-capture/spec.md
        ├── content-conversion/spec.md
        ├── file-output/spec.md
        └── notifications/spec.md
```

## License

Personal project, no license specified. Use at your own risk.
