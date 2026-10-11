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

## [1.2.0] — 2026-10-01

Tagged, never published to RubyGems. Its one change ships with 1.2.1.

### Removed
- `payments.initialize_payment`, an alias of `payments.create`. Call `create`.
