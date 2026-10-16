# Changelog

All notable changes to the `wajub` gem are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
`wajub` uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.4.0] — 2026-10-15

### Added
- **`field_errors` on API errors, every validation message of each field.** A
  `422` can give a field several messages; `errors` keeps only the first one.
  `e.field_errors['amount']` lists them all, in the order the API sent them.
  `errors` is unchanged.
- **`invoices.send_invoice`** sends an invoice to its customer. `invoices.send`
  still does, but it is also the name of Ruby's `send`: prefer `send_invoice`.

### Changed
- **`invoices.send` with a Symbol calls that method**, as Ruby's `send` does,
  for code and libraries that call methods by name.
  `invoices.send(:retrieve, id)` used to try to send an invoice whose id is
  `retrieve`. A String is still an invoice id, whatever it reads.

### Deprecated
- **`listen.config` and `listen.auth`.** The API no longer offers them. To
  receive webhooks on your machine, forward them with the Wajub CLI:
  `wajub listen`. Both warn when Ruby shows deprecation warnings
  (`-W:deprecated`).

### Fixed
- **`webhooks.construct_event` keeps the replay window.** A tolerance of `0` or
  less switched the timestamp check off, so an old delivery sent again was
  accepted. A tolerance that is not a positive number now keeps the default of
  300 seconds; `nil` used to raise `NoMethodError`.

### Security
- **An id that is not a Wajub id is refused before anything is sent.** If an
  id you pass can come from a URL or a form, a call could act on another
  resource of your account: `customers.delete('cus_1/tax_ids/txi_1')` deleted a
  tax ID. An id that is empty, `.` or `..`, or contains `/`, now raises
  `ArgumentError`. Wajub ids never take these forms, so valid calls are
  unchanged.

## [1.3.0] — 2026-10-12

1.2.1 was not published to RubyGems: its changes ship in this release.

### Added
- Tax and Shield methods:
  - `tax.reports`, `tax.list_codes`, `tax.retrieve_code`, `tax.jurisdictions`,
    `tax.thresholds` and `tax.threshold_alerts`;
  - `tax.list_registrations` (a page), `tax.create_registration`,
    `tax.retrieve_registration`, `tax.update_registration` and
    `tax.delete_registration`;
  - `shield.list_blocklist`, `shield.add_to_blocklist` and
    `shield.remove_from_blocklist`.

  The README listed them, and calling one raised `NoMethodError`.

### Fixed
- `customers.delete_tax_id` deletes the customer's tax id. It answered `404`.
- `webhooks.construct_event` with a missing `X-Wajub-Signature` or
  `X-Wajub-Timestamp` header (`nil`) raised `NoMethodError`, which a handler
  rescuing `WebhookSignatureVerificationError` let through as a 500. It now
  raises `WebhookSignatureVerificationError`, as does a timestamp that is not a
  number.

### Changed
- **A create sent again with the same idempotency key while the first is still
  running** now returns the first request's result instead of a `409` error.

## [1.2.0] — 2026-10-01

Not published to RubyGems. Its one change ships with 1.3.0.

### Removed
- `payments.initialize_payment`, an alias of `payments.create`. Call `create`.
