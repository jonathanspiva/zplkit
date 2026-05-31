# Security Policy

## Supported versions

Security fixes are applied to the latest released version of ZPLKit. Please
make sure you are on the most recent release before reporting an issue.

## Reporting a vulnerability

Please report security vulnerabilities **privately**. Do not open a public
issue for a security problem.

Use GitHub's private vulnerability reporting:

1. Go to <https://github.com/jonathanspiva/zplkit/security/advisories/new>
2. Describe the issue, the affected version(s), and steps to reproduce.

You can expect an initial acknowledgement within a few days. Once the issue is
confirmed and a fix is available, a release and (where appropriate) a published
advisory will follow.

## Scope

ZPLKit generates, renders, parses, and transmits label data. Areas most
relevant to security include:

- **ZPL injection / escaping** when label content (barcode payloads, text,
  template substitution values) originates from untrusted input. ZPLKit escapes
  field data, but report any case where untrusted input can break out of a
  field or inject commands.
- **The network/printer transport** (`ZPLKitPrinter`), which opens TCP
  connections and parses printer responses. Report parsing crashes, hangs, or
  unsafe handling of malformed responses.
- **Input parsing** in `ZPLKitRenderer` (malformed ZPL) and `ZPLKitVerifier`
  (untrusted images) that could crash or misbehave.

Issues that require physical access to a printer on a trusted local network, or
that depend on a malicious printer the user has explicitly chosen to connect to,
are lower priority but still welcome.
