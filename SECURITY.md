# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Busy Light, please report it responsibly.

**Do not open a public issue.** Instead, use one of these methods:

- **GitHub:** [Open a private security advisory](https://github.com/swizzlevixen/busylight/security/advisories/new)
- **Email:** Contact the maintainer at the email address listed on their [GitHub profile](https://github.com/swizzlevixen)

## What Qualifies

Examples of security concerns for this project:

- Home Assistant access token exposure (logging, crash reports, export)
- Keychain data leakage
- Code injection via malformed Home Assistant API responses
- Arbitrary code execution through AppleScript or Shortcuts interfaces

## What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if you have one)

## Response Timeline

This is a single-maintainer project. I'll aim to acknowledge reports within 7 days and provide a fix or mitigation plan within 30 days, but timelines may vary.

## Supported Versions

Only the latest release is actively supported with security fixes.
