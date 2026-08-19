# Ledgr

<!-- repo-hygiene: reposhuttle-standard -->

**Flutter mobile application for personal ledger and transaction management.**

## Overview

Flutter mobile application for personal ledger and transaction management.

This README records the repository's purpose, verified local workflow, major technology choices, and maintenance status so the project can be understood without first reverse-engineering the source tree.

## Highlights

- Implementation centered on Dart
- Source and supporting project assets kept together for reproducibility

## Tech stack

Dart, Flutter/Dart

## Quick start

```bash
flutter pub get
flutter run
```

## Configuration

No repository-specific configuration file is required for the basic workflow documented above.

## Project structure

```text
lib/  # shared library code
assets/  # images, fonts, and other project assets
docs/  # project documentation
test/  # automated tests
android/  # Android platform project
ios/  # iOS platform project
```

## Repository status

This repository is maintained as a project reference and portfolio artifact.

## Development

Before submitting a change, run the project's available build or execution workflow and verify the affected behavior manually.
Keep changes focused, avoid committing generated artifacts unless the project already tracks them, and update this README whenever setup or behavior changes.

## Security and configuration hygiene

Keep secrets in local environment variables or an ignored `.env` file. Never commit API keys, access tokens, private keys, production database URLs, or customer data. If a credential is committed, revoke and rotate it; deleting the file in a later commit does not remove it from Git history.

## Contributing

Open an issue or provide context before making a large change. Prefer small pull requests with a clear purpose, verification notes, and screenshots for visible UI changes.

## Additional project notes

Private, offline-first personal finance tracker. Flutter, Android-first.

Every account in one place, expense capture in under 5 seconds, budgets, reports, recurring bills, and debt (udhaar) tracking — all local, no account required, no network permission in v1.

- **Spec**: [PLAN.md](PLAN.md)
- **Domain glossary**: [CONTEXT.md](CONTEXT.md)
- **Decisions**: [docs/adr/](docs/adr/)
- **Agent conventions**: [CLAUDE.md](CLAUDE.md), [docs/agents/](docs/agents/)

Status: pre-code — planning complete, implementation starts at PLAN.md §10 M0.

## License

No license file is currently included. Unless the repository owner states otherwise, the source is not offered under an open-source license.
