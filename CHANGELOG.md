# Changelog

All notable changes to the `wajub` gem are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
`wajub` uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.0] — 2026-10-12

1.2.1 was never published to RubyGems: its changes ship in this release.

### Added
- The tax and Shield methods the other server SDKs already had, with the
  same paths and the same results as the Python SDK:
  - `tax.reports`, `tax.list_codes`, `tax.retrieve_code`, `tax.jurisdictions`,
    `tax.thresholds` and `tax.threshold_alerts`;
  - `tax.list_registrations` (a page), `tax.create_registration`,
    `tax.retrieve_registration`, `tax.update_registration` and
    `tax.delete_registration`;
  - `shield.list_blocklist`, `shield.add_to_blocklist` and
    `shield.remove_from_blocklist`.

  The README listed them, and calling one raised `NoMethodError`.

### Fixed
- `customers.delete_tax_id` called `DELETE /customers/%2Fcustomers%2F…` and
  answered `404`: the nested path went through the resource's own `delete`,
  which takes an id and encodes it as one path segment. It now calls
  `DELETE /customers/{id}/tax_ids/{tax_id}`.
- `webhooks.construct_event` with a missing `X-Wajub-Signature` or
  `X-Wajub-Timestamp` header (`nil`) raised `NoMethodError`, which a handler
  rescuing `WebhookSignatureVerificationError` let through as a 500. It now
  raises `WebhookSignatureVerificationError`, as does a timestamp that is not a
  number.

### Changed
- **The `409` for an `Idempotency-Key` still being processed is retried.** A
  call sent again after a timeout can reach the API while the first one is still
  running; the API answers `409` with `errors.idempotency_key`. The client now
  waits 2 then 4 seconds and asks again with the same key, within its usual 2
  retries, and returns the first request's result. Every other `409` is still
  raised at once.

## [1.2.0] — 2026-10-01

Tagged, never published to RubyGems. Its one change ships with 1.3.0.

### Removed
- `payments.initialize_payment`, an alias of `payments.create`. Call `create`.
