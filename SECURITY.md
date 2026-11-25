# Security Policy

## Scope

`AemiSDR` is a local, offline-first Swift graphics and SwiftUI rendering library.

- **Zero network access:** `AemiSDR` makes no outbound network requests and collects no telemetry.
- **Strict memory safety:** Compiled in Swift 6 language mode with `.strictMemorySafety()` and warnings as errors.
- **Explicit private-API control:** macOS backdrop private API usage is opt-in and gated via `PrivateAPIPolicy`.

## Supported Versions

Security fixes are released on the latest version on `main`.

## Reporting a Vulnerability

Report security issues privately through [GitHub Security Advisories](https://github.com/Aemi-Studio/AemiSDR/security/advisories/new).

## Response targets (best-effort, solo maintainer)

This project is maintained by a single developer on a best-effort basis; the targets below are realistic guidelines
rather than contractual SLAs:

| Milestone | Best-effort target |
| --- | --- |
| Private acknowledgement | Within **7–14 days** |
| Initial triage & severity confirmation | Within **30 days** |
| Fix & advisory — **Critical** | Within **30 days** (sooner when actively exploited) |
| Fix & advisory — **High** | Within **60–90 days** |
| Fix — **Medium / Low** | Next scheduled release, as time permits |

Security fixes in released versions are published with a GitHub Security Advisory (and CVE identifier where applicable)
and named in the release notes.
