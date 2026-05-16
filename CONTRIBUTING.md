# Contributing to cdlg

## Report a bug

Open an issue and include:
- OS and bash version (`bash --version`)
- Claude Code version (`claude --version`)
- What you did, what you expected, what happened instead

## Suggest a feature

Open an issue before writing code — cdlg is intentionally minimal.
A feature fits if it needs no new dependencies and works in bash 3.2+.

## Pull requests

- One change per PR
- Test on bash 3.2+ if possible (macOS ships with it)
- No external dependencies — bash + python3 stdlib only
- Keep `cdlg.sh` as a single file

## Good first issues

Look for issues labelled `good first issue`. Current candidates:
- Document what the `↕` counter means in the session list
- Add `--help` flag output
- Test and report compatibility on FreeBSD / Alpine

## Questions

Just open an issue — no mailing list, no Discord, no overhead.
