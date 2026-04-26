# notifications Specification

## Purpose

Define how `readit` surfaces success and failure to the user via cross-platform desktop notifications. Because `readit` is typically invoked from a hotkey or workflow runner where the terminal is not visible, notifications are the primary feedback channel.

## Requirements

### Requirement: Notifications fire on terminal outcomes

`readit` SHALL emit exactly one desktop notification per invocation, on either success or fatal failure. No notification SHALL be emitted on the silent no-op path (clipboard is not a URL).

#### Scenario: Success notification on file write
- **WHEN** the output file has been written to disk successfully
- **THEN** `readit` SHALL emit a desktop notification with title `readit ✓ saved`
- **AND** the message body SHALL contain the article title on the first line and the basename of the written file on the second line

#### Scenario: Error notification on fatal failures
- **WHEN** `readit` aborts due to a fatal error (clipboard read fail, missing output dir, mkdir fail, write fail)
- **THEN** `readit` SHALL emit an alert-style desktop notification with title `readit ✗ error`
- **AND** the message body SHALL contain the error reason

#### Scenario: No notification when clipboard is not a URL
- **WHEN** the clipboard does not contain a valid `http(s)` URL
- **THEN** `readit` MUST NOT emit any desktop notification
- **AND** SHALL exit silently with code `0`

### Requirement: Notifications can be disabled

Users SHALL be able to disable notifications globally per invocation via either of two mechanisms:

1. The `--quiet` command-line flag.
2. The `READIT_NOTIFY=0` environment variable.

#### Scenario: --quiet flag suppresses both success and error notifications
- **WHEN** `readit --quiet` is invoked
- **THEN** no desktop notification SHALL be emitted, regardless of outcome
- **AND** stdout/stderr output SHALL remain unchanged

#### Scenario: READIT_NOTIFY=0 suppresses notifications
- **WHEN** the environment variable `READIT_NOTIFY` is set to the literal string `0`
- **THEN** no desktop notification SHALL be emitted, regardless of outcome
- **AND** behavior SHALL be equivalent to `--quiet`

#### Scenario: Other READIT_NOTIFY values do not suppress
- **WHEN** `READIT_NOTIFY` is unset, empty, or set to any value other than `0` (e.g. `1`, `true`, `yes`)
- **THEN** notifications SHALL be enabled (subject to the `--quiet` flag overriding)

### Requirement: Notification delivery is best-effort and non-blocking

A failure to deliver a desktop notification MUST NOT change the exit code, stdout, or stderr of `readit`. The CLI SHALL prefer printing the result and exiting cleanly over guaranteeing notification delivery.

#### Scenario: Notification API failure is swallowed
- **WHEN** the underlying notification library returns an error (no notification daemon, missing entitlement, headless system)
- **THEN** `readit` SHALL exit with the same status code it would have exited with otherwise
- **AND** the printed stdout path on success SHALL still be present

### Requirement: Cross-platform delivery via beeep

Notifications SHALL be delivered via the `gen2brain/beeep` library, which uses native APIs on each platform without CGO.

#### Scenario: macOS uses osascript
- **WHEN** `readit` runs on macOS
- **THEN** notifications SHALL be delivered through `osascript display notification` (the platform behavior of `beeep`)

#### Scenario: Linux uses libnotify
- **WHEN** `readit` runs on Linux with a notification daemon present
- **THEN** notifications SHALL be delivered through `notify-send` / libnotify

#### Scenario: Windows uses native toast
- **WHEN** `readit` runs on Windows
- **THEN** notifications SHALL be delivered through the native Windows toast API
