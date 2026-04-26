# readit Project

## Purpose

A single-binary CLI that captures whatever URL is on the system clipboard and saves it as an Obsidian-compatible Markdown file in a configurable folder. Built for the "save now, read later" workflow.

## Stack

- Language: Go (≥ 1.22)
- Distribution: `go install` → single static binary on `$PATH`
- Platforms: macOS, Linux, Windows

## Capabilities

| Capability | Spec |
|-----------|------|
| Read clipboard, validate URL, no-op if invalid | [clipboard-capture](specs/clipboard-capture/spec.md) |
| Fetch URL, dispatch by content type (HTML / Markdown / plain), produce frontmatter + body | [content-conversion](specs/content-conversion/spec.md) |
| Resolve output dir, slugify filename, write `.md` | [file-output](specs/file-output/spec.md) |
| Surface success / failure via desktop notification | [notifications](specs/notifications/spec.md) |

## Non-goals

- No headless browser. SPA / client-rendered pages are best-effort.
- No queue, no scheduler, no retries. One URL per invocation.
- No frontmatter fields beyond `title`, `summary`, `date`, `url`.
- No GUI, no daemon, no MCP server.

## Configuration surface

| Surface | Source | Default |
|---------|--------|---------|
| URL input | `--url` flag, then positional arg, then clipboard | clipboard |
| Output directory | `--dir <path>` flag, then `$READIT_DIR` | _(no default — error if unset)_ |
| Notifications | `--quiet` flag, then `$READIT_NOTIFY=0` | enabled |
