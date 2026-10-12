# Changelog

All notable changes to the `wajub` gem are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
`wajub` uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.1] — 2026-10-11

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

Tagged, never published to RubyGems. Its one change ships with 1.2.1.

### Removed
- `payments.initialize_payment`, an alias of `payments.create`. Call `create`.
