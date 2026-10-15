# Wajub Ruby SDK

[![Gem Version](https://img.shields.io/gem/v/wajub)](https://rubygems.org/gems/wajub)
[![Ruby](https://img.shields.io/badge/Ruby-3.1%2B-red)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Official server-side SDK for the [Wajub API](https://docs.wajub.com): create payments, confirm them, pay out and verify webhooks from your Ruby backend.

It runs on your server with a secret (`sk.…`, `sk_test.…`) or restricted (`rk.…`, `rk_test.…`) API key. Never expose these keys in client-side code: in the browser, use [Wajub.js](https://docs.wajub.com/libraries/components/js) with your publishable key (`pk.…`, `pk_test.…`).

## Requirements

| Requirement | Version |
|-------------|---------|
| Ruby | 3.1 or later |

No other gem is needed.

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

Amounts are in the currency's **main unit**: `12.50` for GHS 12.50, `5000` for XAF 5,000.

```ruby
require 'wajub'

client = Wajub::Client.new(
  api_key: ENV.fetch('WAJUB_API_KEY'),
  webhook_secret: ENV.fetch('WAJUB_WEBHOOK_SECRET')
)

payment = client.payments.create(
  'amount' => 15_000,
  'currency' => 'XAF',
  'email' => 'buyer@example.com',
  'reference' => 'order-1042',
  'callback' => 'https://shop.example.com/order/complete'
)

# Redirect the customer to payment.authorization_url,
# or mount payment.authorization_token with Wajub.js in your page.
```

Then confirm the result on your server: handle the `payment.succeeded` webhook, or call `client.payments.retrieve(payment.id)`.

Parameters go in as a hash with the API's field names. `create` and `retrieve` return an object whose fields read as methods (`payment.authorization_url`) or with brackets (`payment['authorization_url']`). Use brackets for an optional field: a method raises `NoMethodError` when the field is absent, brackets return `nil`.

## Configuration

| Keyword | Description |
|---------|-------------|
| `api_key` | Secret or restricted API key (`sk.…`, `sk_test.…`, `rk.…`, `rk_test.…`). Falls back to `WAJUB_API_KEY`. |
| `webhook_secret` | Webhook signing secret (`whsec_…`), needed only for `webhooks.construct_event`. Falls back to `WAJUB_WEBHOOK_SECRET`. |

An empty key raises `ArgumentError` when the client is built.

## Resources

| Purpose | Property | Methods |
|---------|----------|---------|
| Payments | `client.payments` | `create`, `retrieve`, `list`, `cancel`, `process`, `process_split`, `list_refunds` |
| Refunds | `client.refunds` | `create`, `retrieve`, `list` |
| Customers | `client.customers` | `create`, `retrieve`, `update`, `delete`, `list`, `block`, `unblock`, `activate`, `deactivate`, `list_tax_ids`, `create_tax_id`, `delete_tax_id` |
| Payment links | `client.links` | `create`, `retrieve`, `update`, `delete`, `list` |
| Invoices | `client.invoices` | `create`, `retrieve`, `update`, `delete`, `list`, `send_invoice`, `mark_paid`, `cancel` |
| Payouts | `client.transfers` | `create`, `retrieve`, `list` |
| Payout recipients | `client.beneficiaries` | `create`, `retrieve`, `update`, `delete`, `list` |
| Destination checks | `client.identity` | `resolve`, `validate` |
| Balance | `client.balance` | `retrieve` |
| Disputes | `client.disputes` | `list`, `retrieve`, `submit_evidence`, `accept`, `close`, `send_message` |
| Events | `client.events` | `list`, `retrieve`, `resend` |
| Webhook endpoints | `client.webhook_endpoints` | `create`, `retrieve`, `update`, `delete`, `list`, `rotate_secret` |
| Webhook verification | `client.webhooks` | `construct_event` |
| Connected accounts (Sync) | `client.accounts` | `create`, `retrieve`, `update`, `delete`, `list`, `regenerate_token` |
| Tax | `client.tax` | `get_settings`, `update_settings`, `rates`, `calculate`, `reports`, `list_codes`, `retrieve_code`, `list_registrations`, `create_registration`, `retrieve_registration`, `update_registration`, `delete_registration`, `jurisdictions`, `thresholds`, `threshold_alerts` |
| Fraud (Shield) | `client.shield` | `get_settings`, `update_settings`, `stats`, `list_blocklist`, `add_to_blocklist`, `remove_from_blocklist` |
| Reference data | `client.global` | `ping`, `channels`, `countries`, `currencies` |

## Acting for a connected account

Pass the connected account with `sync` in the call's options:

```ruby
client.payments.create(params, Wajub::RequestOptions.new(sync: 'acct_sync_ref'))
```

## Webhooks

Pass the **raw request body**, not `params`, with the `X-Wajub-Signature` and `X-Wajub-Timestamp` headers. In Rails, build the client once in an initializer and share it:

```ruby
# config/initializers/wajub.rb
WAJUB = Wajub::Client.new # reads WAJUB_API_KEY and WAJUB_WEBHOOK_SECRET
```

```ruby
class WajubWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    event = WAJUB.webhooks.construct_event(
      request.raw_post,
      request.headers['X-Wajub-Signature'],
      request.headers['X-Wajub-Timestamp']
    )

    case event['event']
    when 'payment.succeeded'
      # fulfil the order
    end

    head :ok
  rescue Wajub::WebhookSignatureVerificationError
    head :bad_request
  end
end
```

A delivery that does not verify, or that lacks one of the headers, raises `Wajub::WebhookSignatureVerificationError`. If your server's clock drifts, pass a tolerance in seconds as a fourth argument.

## Pagination

`list` returns a page you can walk one page at a time, or iterate across all pages. Its rows are plain hashes:

```ruby
page = client.payments.list('per_page' => 50)
puts page.data, page.meta, page.has_more

next_page = page.next_page if page.has_more

page.auto_paging_each do |payment|
  puts "#{payment['id']} #{payment['status']}"
end
```

## Idempotency

Temporary failures are retried for you. To make a create safe to repeat on your side too, after a restart or in a job retry, pass your own key:

```ruby
client.payments.create(
  params,
  Wajub::RequestOptions.new(idempotency_key: "order-#{order_id}")
)
```

## Error handling

API errors raise a subclass of `Wajub::WajubError`:

```ruby
begin
  client.payments.create(params)
rescue Wajub::InvalidRequestError => e
  puts e.errors # field-level validation errors
rescue Wajub::AuthenticationError
  # check your API key
rescue Wajub::RateLimitError => e
  puts e.retry_after # seconds to wait
rescue Wajub::WajubError => e
  puts e.code, e.http_status, e.message
end
```

| Class | Raised on |
|-------|-----------|
| `Wajub::AuthenticationError` | `401` |
| `Wajub::PermissionError` | `403` |
| `Wajub::NotFoundError` | `404` |
| `Wajub::InvalidRequestError` | `400`, `422` |
| `Wajub::RateLimitError` | `429`, with `retry_after` in seconds |
| `Wajub::ApiConnectionError` | No response: network error or timeout |
| `Wajub::WajubError` | Any other error status, and the parent of all of the above |

Every error carries `message`, `code`, `http_status`, `errors` (one message per field) and `raw` (the response body).

## Testing

Use a sandbox key (`sk_test.…`): the key chooses the environment, and no real money moves. The test phone numbers and cards are on [Test scenarios](https://docs.wajub.com/developer-tools/testing/test-scenarios). To receive webhooks on your machine, forward them with the [Wajub CLI](https://docs.wajub.com/developer-tools/cli/listen).

## Documentation & support

- Documentation: [docs.wajub.com/libraries/sdks/ruby](https://docs.wajub.com/libraries/sdks/ruby)
- Report issues: [github.com/wajubhq/wajub-ruby/issues](https://github.com/wajubhq/wajub-ruby/issues)

## License

MIT — see [LICENSE](LICENSE).
