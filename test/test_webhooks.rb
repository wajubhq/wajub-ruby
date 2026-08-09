# frozen_string_literal: true

require 'test_helper'

class TestWebhooks < Minitest::Test
  SECRET = 'whsec_test_abc123'

  def sign(payload, timestamp)
    "v1=#{Wajub::Crypto.hmac_sha256(SECRET, "#{timestamp}.#{payload}")}"
  end

  def test_construct_event_parses_valid_payload
    payload = '{"event":"payment.succeeded","data":{"id":"trx_1"}}'
    ts = Time.now.to_i
    event = Wajub::Webhooks.new(SECRET).construct_event(payload, sign(payload, ts), ts.to_s)
    assert_equal 'payment.succeeded', event['event']
    assert_equal 'trx_1', event.dig('data', 'id')
  end

  def test_construct_event_rejects_wrong_signature
    payload = '{"event":"payment.succeeded"}'
    assert_raises(Wajub::WebhookSignatureVerificationError) do
      Wajub::Webhooks.new(SECRET).construct_event(payload, 'v1=deadbeef', Time.now.to_i.to_s)
    end
  end

  def test_construct_event_rejects_timestamp_outside_tolerance
    payload = '{"event":"payment.succeeded"}'
    old_ts = Time.now.to_i - 600
    assert_raises(Wajub::WebhookSignatureVerificationError) do
      Wajub::Webhooks.new(SECRET).construct_event(payload, sign(payload, old_ts), old_ts.to_s, 300)
    end
  end

  def test_construct_event_rejects_non_string_payload
    payload = { 'event' => 'payment.succeeded' }
    ts = Time.now.to_i
    assert_raises(ArgumentError) do
      Wajub::Webhooks.new(SECRET).construct_event(payload, 'v1=deadbeef', ts.to_s)
    end
  end

  def test_error_from_response
    error = Wajub::Errors.from_response(422, {
                                          'message' => 'Validation failed',
                                          'code' => 'validation_error',
                                          'errors' => { 'amount' => ['Must be positive'] }
                                        })
    assert_instance_of Wajub::InvalidRequestError, error
    assert_equal 'Validation failed', error.message
    assert_equal 'Must be positive', error.errors['amount']
  end
end
