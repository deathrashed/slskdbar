# Contributing

Contributions are welcome.

## Before opening a change

1. Search existing issues and pull requests.
2. Keep changes focused and avoid adding dependencies unless the benefit is
   clear.
3. Preserve the event-driven design. Background polling should not be added for
   convenience.
4. Do not include API keys, slskd configuration files, usernames, transfer
   history, or local filesystem details in fixtures, screenshots, or logs.

## Development checks

Run the following before opening a pull request:

```sh
swift test
swift build -c release
plutil -lint Info.plist
```

For UI changes, also build the app with `bash scripts/build-app.sh` and check the
real menu bar interface. Packaging changes should additionally run
`bash scripts/build-dmg.sh`. Include the macOS version and slskd version used
during manual testing in the pull request.

## Pull requests

- Explain the user-visible result.
- Keep unrelated cleanup out of the change.
- Add or update tests when behavior changes.
- Update `CHANGELOG.md` for user-visible changes.
- Note anything that could not be tested.
