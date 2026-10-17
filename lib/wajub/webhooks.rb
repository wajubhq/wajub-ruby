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

    # A missing signature or timestamp header (nil, as request.headers returns
    # it) raises WebhookSignatureVerificationError, like a wrong one.
    #
    # +tolerance+ is the replay window in seconds. Anything but a positive
    # number (0, a negative number, nil, a String) keeps the default of 300.
    def construct_event(payload, signature, timestamp, tolerance = DEFAULT_TOLERANCE)
      raise ArgumentError, 'Wajub: webhook_secret is required for construct_event' if @secret.empty?
      if signature.to_s.empty? || timestamp.to_s.empty?
        raise WebhookSignatureVerificationError, 'Missing X-Wajub-Signature or X-Wajub-Timestamp header.'
      end
      raise WebhookSignatureVerificationError, 'Invalid webhook signature format. Expected v1={hash}.' unless signature.start_with?('v1=')
      raise ArgumentError, 'Wajub: payload must be the raw request body as a String, not a parsed object' unless payload.is_a?(String)

      body = payload
      expected = Crypto.hmac_sha256(@secret, "#{timestamp}.#{body}")
      received = signature.delete_prefix('v1=')

      raise WebhookSignatureVerificationError, 'Webhook signature verification failed.' unless Crypto.timing_safe_equal(expected, received)

      ts = Float(timestamp, exception: false)
      raise WebhookSignatureVerificationError, 'Invalid webhook timestamp.' unless ts&.finite?

      window = replay_window(tolerance)
      drift = (Time.now.to_i - ts).abs
      if drift > window
        raise WebhookSignatureVerificationError,
              "Timestamp outside tolerance zone (#{drift.to_i}s drift, allowed #{window}s)."
      end

      event = JSON.parse(body)
      raise WebhookSignatureVerificationError, 'Invalid webhook payload JSON.' unless event.is_a?(Hash)

      event
    end

    private

    # A tolerance of 0 or less used to switch the timestamp check off, which let
    # a replayed delivery through.
    def replay_window(tolerance)
      valid = tolerance.is_a?(Numeric) && tolerance.real? && tolerance.finite? && tolerance.positive?
      valid ? tolerance : DEFAULT_TOLERANCE
    end
  end
end
