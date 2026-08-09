# frozen_string_literal: true

require_relative 'http/http_utils'
require_relative 'http/base_client'
require_relative 'resources'
require_relative 'webhooks'

module Wajub
  class Client
    attr_reader :global, :payments, :customers, :refunds, :transfers, :beneficiaries,
                :links, :balance, :events, :accounts, :webhook_endpoints, :invoices,
                :disputes, :identity, :tax, :shield, :listen, :webhooks

    def initialize(api_key: nil, webhook_secret: nil, idempotency_key_prefix: 'wajub', transport: nil)
      key = HttpUtils.normalize_api_key(api_key || ENV.fetch('WAJUB_API_KEY', ''))
      raise ArgumentError, 'Wajub: api_key is required' if key.empty?

      base_url = HttpUtils.api_url
      prefix = idempotency_key_prefix
      @transport = transport

      @global = GlobalResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @payments = PaymentsResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @customers = CustomersResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @refunds = CrudResource.new(key, base_url, 'refunds', 'refund', 'refunds', prefix, transport: shared_transport(base_url))
      @transfers = CrudResource.new(key, base_url, 'transfers', 'transfer', 'transfers', prefix, transport: shared_transport(base_url))
      @beneficiaries = CrudResource.new(key, base_url, 'beneficiaries', 'beneficiary', 'beneficiaries', prefix, transport: shared_transport(base_url))
      @links = CrudResource.new(key, base_url, 'links', 'link', 'links', prefix, transport: shared_transport(base_url))
      @balance = BalanceResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @events = EventsResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @accounts = AccountsResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @webhook_endpoints = WebhookEndpointsResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @invoices = InvoicesResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @disputes = DisputesResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @identity = IdentityResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @tax = TaxResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @shield = ShieldResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @listen = ListenResource.new(key, base_url, prefix, transport: shared_transport(base_url))
      @webhooks = Webhooks.new(webhook_secret || ENV.fetch('WAJUB_WEBHOOK_SECRET', ''))
    end

    private

    def shared_transport(base_url)
      @transport || @shared ||= NetHttpTransport.new(base_url, user_agent: "wajub-ruby/#{VERSION}")
    end
  end
end
