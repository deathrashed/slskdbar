# Security Policy

## Supported versions

Security fixes are applied to the latest released version.

## Reporting a vulnerability

Please use GitHub's private security advisory feature for the repository rather
than opening a public issue. Include the affected version, reproduction steps,
impact, and any suggested mitigation.

Do not include a real slskd API key, configuration file, username, transfer
history, or private filesystem paths in a report.

## Local credentials

slskdbar reads the configured slskd API key directly from the runtime
`slskd.yml` file. It does not save the key in app preferences. Access to the
runtime configuration therefore follows the permissions of the current macOS
account.
