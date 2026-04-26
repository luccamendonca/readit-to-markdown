# clipboard-capture Specification

## Purpose

Define how `readit` resolves the URL it acts on. The CLI accepts a URL from three sources, in priority order, and validates whatever it gets before proceeding. The clipboard remains the default fallback so the bare `readit` command still works for the "copy → run → forget" hotkey workflow.

## Requirements

### Requirement: Three URL input sources with explicit precedence

`readit` SHALL resolve the URL from these sources, in this priority order:

1. The `--url <value>` command-line flag.
2. The first positional argument (`readit <url>`).
3. The system clipboard, read via the OS native API.

The first source that yields a non-empty value SHALL be used. Lower-priority sources MUST NOT be consulted once a higher-priority source provides a value (in particular, the clipboard MUST NOT be read if `--url` or a positional URL is supplied).

#### Scenario: --url flag wins over positional arg
- **WHEN** user runs `readit --url https://a.example/x https://b.example/y`
- **THEN** the URL acted upon SHALL be `https://a.example/x`
- **AND** `https://b.example/y` SHALL be ignored

#### Scenario: Positional arg wins over clipboard
- **WHEN** user runs `readit https://example.com/x` AND the clipboard contains a different URL
- **THEN** the URL acted upon SHALL be `https://example.com/x`
- **AND** the clipboard MUST NOT be read

#### Scenario: Clipboard is read only when no flag/arg supplied
- **WHEN** user runs bare `readit` with no `--url` and no positional arg
- **THEN** the binary SHALL read the system clipboard exactly once
- **AND** SHALL trim leading and trailing whitespace from the clipboard contents

#### Scenario: Clipboard read failure surfaces as fatal error
- **WHEN** the clipboard path is taken AND the OS clipboard API returns an error
- **THEN** `readit` SHALL exit with code `1`
- **AND** SHALL print `error: clipboard read: <reason>` to stderr
- **AND** SHALL fire an error desktop notification unless suppressed

### Requirement: URL validation gates further work

The resolved input (after trimming) SHALL be parsed as a URL. The URL is considered valid only if it parses successfully **and** has scheme `http` or `https` **and** has a non-empty host.

#### Scenario: Valid http(s) URL proceeds to fetch
- **WHEN** the resolved input parses as a URL with scheme `http` or `https` and a non-empty host
- **THEN** `readit` SHALL print `fetching <url>` to stderr
- **AND** SHALL proceed to the content-conversion stage

### Requirement: Validation failure differs by source

Invalid input from the clipboard is a quiet no-op (so a hotkey-bound `readit` does nothing harmful when the clipboard happens to hold non-URL text). Invalid input from `--url` or a positional arg is a loud error (the user explicitly asked to process something).

#### Scenario: Invalid clipboard exits silently
- **WHEN** the clipboard source produced an empty, non-URL, or non-http(s) value
- **THEN** `readit` SHALL print `clipboard not URL, exit` to stderr
- **AND** SHALL exit with code `0`
- **AND** MUST NOT touch the filesystem
- **AND** MUST NOT fire any notification

#### Scenario: Invalid --url flag exits with error
- **WHEN** the `--url` flag was provided AND the value is empty, unparseable, or not http/https
- **THEN** `readit` SHALL exit with code `1`
- **AND** SHALL print `error: flag not a valid http(s) URL: "<value>"` to stderr
- **AND** SHALL fire an error desktop notification unless suppressed

#### Scenario: Invalid positional arg exits with error
- **WHEN** a positional argument was provided AND the value is empty, unparseable, or not http/https
- **THEN** `readit` SHALL exit with code `1`
- **AND** SHALL print `error: arg not a valid http(s) URL: "<value>"` to stderr
- **AND** SHALL fire an error desktop notification unless suppressed

### Requirement: Schemes other than http(s) are rejected

`readit` SHALL treat `file://`, `ftp://`, `mailto:`, `javascript:`, custom-scheme URLs (e.g. `obsidian://`), and any other non-HTTP scheme as invalid for routing purposes, regardless of which input source they came from.

#### Scenario: file:// from clipboard is silent no-op
- **WHEN** the clipboard contains `file:///etc/passwd`
- **THEN** `readit` SHALL exit silently (code `0`) without reading the file

#### Scenario: file:// from --url errors out
- **WHEN** the user runs `readit --url file:///etc/passwd`
- **THEN** `readit` SHALL exit with code `1` and the "flag not a valid http(s) URL" error
