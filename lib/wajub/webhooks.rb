# frozen_string_literal: true

require 'json'

require_relative 'crypto'
require_relative 'errors'

module Wajub
  class Webhooks
    DEFAULT_TOLERANCE = 300

    attr_reader :secret

    def initialize(secret)
      @secret = secret.to_s
    end

    def construct_event(payload, signature, timestamp, tolerance = DEFAULT_TOLERANCE)
      raise ArgumentError, 'Wajub: webhook_secret is required for construct_event' if @secret.empty?
      raise WebhookSignatureVerificationError, 'Invalid webhook signature format. Expected v1={hash}.' unless signature.start_with?('v1=')
      raise ArgumentError, 'Wajub: payload must be the raw request body as a String, not a parsed object' unless payload.is_a?(String)

      body = payload
      expected = Crypto.hmac_sha256(@secret, "#{timestamp}.#{body}")
      received = signature.delete_prefix('v1=')

      raise WebhookSignatureVerificationError, 'Webhook signature verification failed.' unless Crypto.timing_safe_equal(expected, received)

      ts = Float(timestamp)
      raise WebhookSignatureVerificationError, 'Invalid webhook timestamp.' unless ts.finite?

      drift = (Time.now.to_i - ts).abs
      if tolerance.positive? && drift > tolerance
        raise WebhookSignatureVerificationError,
              "Timestamp outside tolerance zone (#{drift.to_i}s drift, allowed #{tolerance}s)."
      end

      event = JSON.parse(body)
      raise WebhookSignatureVerificationError, 'Invalid webhook payload JSON.' unless event.is_a?(Hash)

      event
    end
  end
end
