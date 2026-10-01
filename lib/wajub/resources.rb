# frozen_string_literal: true

require 'uri'

require_relative 'http/base_client'
require_relative 'http/http_utils'
require_relative 'pagination'

module Wajub
  class CrudResource < BaseClient
    def initialize(api_key, base_url, path, singular, plural, idempotency_key_prefix = 'wajub', transport: nil)
      super(api_key, base_url, idempotency_key_prefix, transport: transport)
      @path = path
      @singular = singular
      @plural = plural
    end

    def create(params, options = nil)
      HttpUtils.pick_resource(post("/#{@path}", params, options), @singular)
    end

    def retrieve(id)
      HttpUtils.pick_resource(get("/#{@path}/#{URI.encode_www_form_component(id)}"), @singular)
    end

    def list(params = nil)
      PagedResult.create(self, "/#{@path}", @plural, params)
    end

    def update(id, params, options = nil)
      HttpUtils.pick_resource(put("/#{@path}/#{URI.encode_www_form_component(id)}", params, options), @singular)
    end

    def delete(id, options = nil)
      request('DELETE', "/#{@path}/#{URI.encode_www_form_component(id)}", options: options)
    end
  end

  class PaymentsResource < BaseClient
    def create(params, options = nil)
      to_payment_object(post('/payments', params, options))
    end

    def retrieve(id)
      res = get("/payments/#{URI.encode_www_form_component(id)}")
      to_payment_object('transaction' => HttpUtils.pick_resource(res, 'transaction'))
    end

    def list(params = nil)
      PagedResult.create(self, '/payments', 'transactions', params)
    end

    def cancel(id, options = nil)
      res = delete("/payments/#{URI.encode_www_form_component(id)}", options)
      to_payment_object('transaction' => HttpUtils.pick_resource(res, 'transaction'))
    end

    def process(id, params, options = nil)
      res = post("/payments/#{URI.encode_www_form_component(id)}", params, options)
      to_payment_object('transaction' => HttpUtils.pick_resource(res, 'transaction'))
    end

    def process_split(id, params, options = nil)
      res = post("/payments/#{URI.encode_www_form_component(id)}/splits", params, options)
      to_payment_object('transaction' => HttpUtils.pick_resource(res, 'transaction'))
    end

    def list_refunds(id, params = nil)
      list = HttpUtils.pick_list(get("/payments/#{URI.encode_www_form_component(id)}/refunds", params), 'refunds')
      [list[:data], list[:meta]]
    end

    private

    def to_payment_object(body)
      transaction = HttpUtils.pick_resource(body, 'transaction')
      Payment.new(
        transaction.merge(
          'authorization_token' => body['authorization_token'] || transaction['authorization_token'] || transaction['id'],
          'authorization_url' => body['authorization_url'] || transaction['authorization_url'] || ''
        )
      )
    end
  end

  class GlobalResource < BaseClient
    def ping
      get('/')
    end

    def channels(params = nil)
      list = HttpUtils.pick_list(get('/channels', params), 'channels')
      [list[:data], list[:meta]]
    end

    def countries(params = nil)
      list = HttpUtils.pick_list(get('/countries', params), 'countries')
      [list[:data], list[:meta]]
    end

    def currencies(params = nil)
      list = HttpUtils.pick_list(get('/currencies', params), 'currencies')
      [list[:data], list[:meta]]
    end
  end

  class BalanceResource < BaseClient
    def retrieve
      HttpUtils.pick_resource(get('/balance'), 'balance', 'data')
    end
  end

  class EventsResource < BaseClient
    def list(params = nil)
      PagedResult.create(self, '/events', 'events', params)
    end

    def retrieve(id)
      HttpUtils.pick_resource(get("/events/#{URI.encode_www_form_component(id)}"), 'event')
    end

    def resend(id, options = nil)
      HttpUtils.pick_resource(post("/events/#{URI.encode_www_form_component(id)}/resend", nil, options), 'event')
    end
  end

  class CustomersResource < CrudResource
    def initialize(api_key, base_url, idempotency_key_prefix = 'wajub', transport: nil)
      super(api_key, base_url, 'customers', 'customer', 'customers', idempotency_key_prefix, transport: transport)
    end

    def block(id, params = nil, options = nil)
      HttpUtils.pick_resource(post("/customers/#{URI.encode_www_form_component(id)}/block", params, options), 'customer')
    end

    def unblock(id, options = nil)
      HttpUtils.pick_resource(post("/customers/#{URI.encode_www_form_component(id)}/unblock", nil, options), 'customer')
    end

    def activate(id, options = nil)
      HttpUtils.pick_resource(post("/customers/#{URI.encode_www_form_component(id)}/activate", nil, options), 'customer')
    end

    def deactivate(id, options = nil)
      HttpUtils.pick_resource(post("/customers/#{URI.encode_www_form_component(id)}/deactivate", nil, options), 'customer')
    end

    def list_tax_ids(customer_id)
      list = HttpUtils.pick_list(get("/customers/#{URI.encode_www_form_component(customer_id)}/tax_ids"), 'tax_ids')
      [list[:data], list[:meta]]
    end

    def create_tax_id(customer_id, params, options = nil)
      HttpUtils.pick_resource(post("/customers/#{URI.encode_www_form_component(customer_id)}/tax_ids", params, options), 'tax_id')
    end

    def delete_tax_id(customer_id, tax_id, options = nil)
      delete("/customers/#{URI.encode_www_form_component(customer_id)}/tax_ids/#{URI.encode_www_form_component(tax_id)}", options)
    end
  end

  class AccountsResource < CrudResource
    def initialize(api_key, base_url, idempotency_key_prefix = 'wajub', transport: nil)
      super(api_key, base_url, 'accounts', 'account', 'accounts', idempotency_key_prefix, transport: transport)
    end

    def regenerate_token(id, options = nil)
      HttpUtils.pick_resource(post("/accounts/#{URI.encode_www_form_component(id)}/token", nil, options), 'account')
    end
  end

  class WebhookEndpointsResource < CrudResource
    def initialize(api_key, base_url, idempotency_key_prefix = 'wajub', transport: nil)
      super(api_key, base_url, 'webhooks', 'endpoint', 'endpoints', idempotency_key_prefix, transport: transport)
    end

    def rotate_secret(id, options = nil)
      HttpUtils.pick_resource(post("/webhooks/#{URI.encode_www_form_component(id)}/rotate-secret", nil, options), 'endpoint')
    end
  end

  class InvoicesResource < CrudResource
    def initialize(api_key, base_url, idempotency_key_prefix = 'wajub', transport: nil)
      super(api_key, base_url, 'invoices', 'invoice', 'invoices', idempotency_key_prefix, transport: transport)
    end

    def send(id, options = nil)
      HttpUtils.pick_resource(post("/invoices/#{URI.encode_www_form_component(id)}/send", nil, options), 'invoice')
    end

    def mark_paid(id, params = nil, options = nil)
      HttpUtils.pick_resource(post("/invoices/#{URI.encode_www_form_component(id)}/mark-paid", params, options), 'invoice')
    end

    def cancel(id, options = nil)
      HttpUtils.pick_resource(post("/invoices/#{URI.encode_www_form_component(id)}/cancel", nil, options), 'invoice')
    end
  end

  class DisputesResource < BaseClient
    def list(params = nil)
      PagedResult.create(self, '/disputes', 'disputes', params)
    end

    def retrieve(id)
      HttpUtils.pick_resource(get("/disputes/#{URI.encode_www_form_component(id)}"), 'dispute')
    end

    def submit_evidence(id, params, options = nil)
      HttpUtils.pick_resource(post("/disputes/#{URI.encode_www_form_component(id)}/submit-evidence", params, options), 'dispute')
    end

    def accept(id, options = nil)
      HttpUtils.pick_resource(post("/disputes/#{URI.encode_www_form_component(id)}/accept", nil, options), 'dispute')
    end

    def close(id, options = nil)
      HttpUtils.pick_resource(post("/disputes/#{URI.encode_www_form_component(id)}/close", nil, options), 'dispute')
    end

    def send_message(id, params, options = nil)
      HttpUtils.pick_resource(post("/disputes/#{URI.encode_www_form_component(id)}/messages", params, options), 'dispute')
    end
  end

  class IdentityResource < BaseClient
    def resolve(params, options = nil)
      HttpUtils.pick_resource(post('/identity/resolve', params, options), 'identity')
    end

    def validate(params, options = nil)
      HttpUtils.pick_resource(post('/identity/validate', params, options), 'identity')
    end
  end

  class TaxResource < BaseClient
    def get_settings
      HttpUtils.pick_resource(get('/tax/settings'), 'tax', 'settings')
    end

    def update_settings(params, options = nil)
      HttpUtils.pick_resource(put('/tax/settings', params, options), 'tax', 'settings')
    end

    def rates(params = nil)
      list = HttpUtils.pick_list(get('/tax/rates', params), 'rates', 'tax_rates')
      [list[:data], list[:meta]]
    end

    def calculate(params, options = nil)
      HttpUtils.pick_resource(post('/tax/calculate', params, options), 'tax', 'calculation')
    end
  end

  class ShieldResource < BaseClient
    def get_settings
      HttpUtils.pick_resource(get('/shield/settings'), 'shield', 'settings')
    end

    def update_settings(params, options = nil)
      HttpUtils.pick_resource(put('/shield/settings', params, options), 'shield', 'settings')
    end

    def stats(params = nil)
      HttpUtils.pick_resource(get('/shield/stats', params), 'shield', 'stats')
    end
  end

  class ListenResource < BaseClient
    def config
      HttpUtils.pick_resource(get('/listen/config'), 'config', 'listen')
    end

    def auth(params, options = nil)
      HttpUtils.pick_resource(post('/listen/auth', params, options), 'auth', 'listen')
    end
  end
end
