# Wajub Ruby SDK

[![Gem Version](https://img.shields.io/gem/v/wajub)](https://rubygems.org/gems/wajub)
[![Ruby](https://img.shields.io/badge/Ruby-3.1%2B-red)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Official **server-side** SDK for the [Wajub merchant API](https://docs.wajub.com). Accept mobile-money and card payments across Africa with a Stripe-inspired, resource-oriented client.

Use **[Wajub.js](https://docs.wajub.com/libraries/components/js)** for embedded checkout in the browser. Use this SDK on your backend with a secret (`sk_`) or restricted (`rk_`) API key — never expose secret keys in client-side code.

## Features

- Resource-oriented API (`client.payments`, `client.customers`, …)
- Automatic `Idempotency-Key` on mutating requests (override per call)
- Typed errors per HTTP status (`AuthenticationError`, `RateLimitError`, …)
- Automatic retries on 429 and 5xx (max 2, exponential backoff)
- Page-based pagination with `auto_paging_each` and `next_page`
- Webhook signature verification (HMAC-SHA256, timestamp tolerance)
- Zero third-party runtime dependencies (stdlib only)

## Requirements

| Requirement | Version |
|-------------|---------|
| Ruby | 3.1 or later |
| Dependencies | Standard library only (`net/http`, `openssl`, `json`) |

## Installation

Add to your Gemfile:

```ruby
gem 'wajub', '~> 1.3'
```

Or install directly:

```bash
gem install wajub
```

## Quick start

Amounts are passed in the **smallest currency unit** (e.g. cents for EUR/USD; whole francs for XAF).

### Redirect checkout

```ruby
require 'wajub'

client = Wajub::Client.new(api_key: ENV['WAJUB_API_KEY'])

payment = client.payments.create(
  'amount' => 15_000,
  'currency' => 'XAF',
  'email' => 'buyer@example.com',
  'callback' => 'https://shop.example.com/order/complete'
)

puts payment.authorization_url
```

### Inline / overlay (embed token)

```ruby
embed = client.payments.create(
  'amount' => 15_000,
  'currency' => 'XAF',
  'metadata' => { 'mode' => 'embed' }
)

# Pass to Wajub.js: embed.authorization_token
```

`create()` and `retrieve()` return a typed `Payment` object — prefer method access (`payment.authorization_url`). List pages from `list()` yield plain hashes; bracket syntax (`payment['…']`) remains available on typed objects.

## Rails

```ruby
# config/initializers/wajub.rb
WajubClient = Wajub::Client.new(
  api_key: Rails.application.credentials.dig(:wajub, :api_key) || ENV['WAJUB_API_KEY'],
  webhook_secret: ENV['WAJUB_WEBHOOK_SECRET']
)
```

### Webhook controller

Use the **raw request body**:

```ruby
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def wajub
    event = WajubClient.webhooks.construct_event(
      request.body.read,  # raw body — not params
      request.headers['X-Wajub-Signature'],
      request.headers['X-Wajub-Timestamp']
    )

    case event['event']
    when 'payment.succeeded'
      # fulfill order
    end

    head :ok
  rescue Wajub::WebhookSignatureVerificationError
    head :bad_request
  end
end
```

## Configuration

| Variable | Description |
|----------|-------------|
| `WAJUB_API_KEY` | Secret or restricted API key (`sk_`, `sk_test.`, `rk_`, …) |
| `WAJUB_WEBHOOK_SECRET` | Webhook signing secret (`whsec_`) for `construct_event()` |

Test mode is selected by your API key prefix (`sk_test.…`), not by the API URL. Production calls always go to `https://api.wajub.com`.

## Resources (merchant API)

| Property | Methods |
|----------|---------|
| `client.global` | `ping`, `channels`, `countries`, `currencies` |
| `client.payments` | `create`, `retrieve`, `list`, `cancel`, `process`, `process_split`, `list_refunds` |
| `client.customers` | `create`, `retrieve`, `update`, `delete`, `list`, `block`, `unblock`, `activate`, `deactivate`, `list_tax_ids`, `create_tax_id`, `delete_tax_id` |
| `client.refunds` | `create`, `retrieve`, `list` |
| `client.transfers` | `create`, `retrieve`, `list` |
| `client.beneficiaries` | `create`, `retrieve`, `update`, `delete`, `list` |
| `client.links` | `create`, `retrieve`, `update`, `delete`, `list` |
| `client.invoices` | `create`, `retrieve`, `update`, `delete`, `list`, `send`, `mark_paid`, `cancel` |
| `client.accounts` | `create`, `retrieve`, `update`, `delete`, `list`, `regenerate_token` |
| `client.webhook_endpoints` | `create`, `retrieve`, `update`, `delete`, `list`, `rotate_secret` |
| `client.balance` | `retrieve` |
| `client.events` | `list`, `retrieve`, `resend` |
| `client.disputes` | `list`, `retrieve`, `submit_evidence`, `accept`, `close`, `send_message` |
| `client.identity` | `resolve`, `validate` |
| `client.tax` | `get_settings`, `update_settings`, `rates`, `calculate`, `reports`, `list_codes`, `retrieve_code`, `list_registrations`, `create_registration`, `retrieve_registration`, `update_registration`, `delete_registration`, `jurisdictions`, `thresholds`, `threshold_alerts` |
| `client.shield` | `get_settings`, `update_settings`, `stats`, `list_blocklist`, `add_to_blocklist`, `remove_from_blocklist` |
| `client.listen` | `config`, `auth` |
| `client.webhooks` | `construct_event` (local — no HTTP) |

## Sync (Connect)

```ruby
client.payments.create(params, Wajub::RequestOptions.new(sync: 'acct_sync_ref'))
```

## Webhooks

```ruby
begin
  event = client.webhooks.construct_event(
    request.body.read,  # String — raw body bytes
    request.env['HTTP_X_WAJUB_SIGNATURE'],
    request.env['HTTP_X_WAJUB_TIMESTAMP']
  )
rescue Wajub::WebhookSignatureVerificationError
  halt 400
end

case event['event']
when 'payment.succeeded'
  # fulfill order
end
```

During local development, use the [Wajub CLI](https://github.com/wajubhq/wajub-cli) to forward webhooks to your machine.

## Pagination

```ruby
page = client.payments.list('per_page' => 50)

page.auto_paging_each do |payment|
  puts "#{payment['id']} #{payment['status']}"
end

# Manual page control
first = client.payments.list
second = first.next_page if first.has_more
```

## Idempotency

POST and PUT requests automatically receive an `Idempotency-Key` header. Pass your own:

```ruby
client.payments.create(
  params,
  Wajub::RequestOptions.new(idempotency_key: "order-#{order_id}")
)
```

## Error handling

```ruby
begin
  client.payments.create(params)
rescue Wajub::InvalidRequestError => e
  puts e.errors   # field-level validation errors
rescue Wajub::AuthenticationError
  # 401 — bad API key
rescue Wajub::RateLimitError
  # 429 — back off and retry
end
```

## Development

```bash
bundle install
bundle exec rake test
```

## Documentation & support

- Full API reference: [docs.wajub.com/libraries/sdks/ruby](https://docs.wajub.com/libraries/sdks/ruby)
- Report issues: [github.com/wajubhq/wajub-ruby/issues](https://github.com/wajubhq/wajub-ruby/issues)

## License

MIT — see [LICENSE](LICENSE).
