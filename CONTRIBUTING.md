# Contributing to SaasCode Kit

First off, thanks for considering contributing! This kit is open-source and community contributions make it better for everyone.

## How to Contribute

### Reporting Bugs

- Open an [issue](https://github.com/Saitata7/saascode-kit/issues) with a clear title
- Describe what happened vs. what you expected
- Include your OS, shell version, and any relevant manifest config

### Suggesting Features

- Open an issue with the `enhancement` label
- Describe the use case — what problem does it solve?
- If possible, suggest an implementation approach

### Pull Requests

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test manually with a real project (run `saascode init` or the relevant IDE command)
5. Commit with a clear message
6. Push and open a PR against `main`

### What We're Looking For

- New Semgrep rules for common SaaS patterns
- New Claude Code skills for developer workflows
- Cursor/Windsurf rule improvements
- Bug fixes in shell scripts
- Documentation improvements
- Support for additional CI providers (GitLab, Bitbucket)
- Support for additional frameworks beyond NestJS/Next.js

### Code Style

- Shell scripts: POSIX-compatible where possible, `bash` when needed
- Use `shellcheck` if available
- Keep functions small and focused
- Add comments for non-obvious logic

### Testing

There's no automated test suite yet (contributions welcome!). For now:
- Test `saascode init` end-to-end with a sample project
- Test individual IDE commands (`saascode claude`, `saascode cursor`, `saascode windsurf`)
- Verify template placeholders are replaced correctly
- Check that `saascode update` syncs without errors

## Code of Conduct

Be respectful, constructive, and inclusive. We're all here to build better tools.

## Questions?

Open an issue or reach out to [@Saitata7](https://github.com/Saitata7).
