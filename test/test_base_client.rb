# frozen_string_literal: true

require 'test_helper'

class TestBaseClient < Minitest::Test
  def test_sends_raw_api_key_in_authorization_header
    mock = Wajub::MockTransport.new([{ status: 200, body: { 'ok' => true } }])
    client = Wajub::BaseClient.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    client.get('/ping')

    assert_equal API_KEY, mock.last_request[:headers]['Authorization']
    assert_equal 'application/json', mock.last_request[:headers]['Accept']
  end

  def test_post_includes_idempotency_key_by_default
    mock = Wajub::MockTransport.new([{ status: 200, body: { 'transaction' => { 'id' => 'pay_1' } } }])
    client = Wajub::BaseClient.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    client.post('/payments', { 'amount' => 1000 })

    key = mock.last_request[:headers]['Idempotency-Key']
    assert key.start_with?('wajub-')
  end

  def test_post_honors_custom_idempotency_key_and_sync_header
    mock = Wajub::MockTransport.new([{ status: 200, body: { 'transaction' => { 'id' => 'pay_1' } } }])
    client = Wajub::BaseClient.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)
    options = Wajub::RequestOptions.new(idempotency_key: 'custom-key-123', sync: 'acct_sync_ref')

    client.post('/payments', { 'amount' => 1000 }, options)

    assert_equal 'custom-key-123', mock.last_request[:headers]['Idempotency-Key']
    assert_equal 'acct_sync_ref', mock.last_request[:headers]['X-Sync']
  end

  def test_get_does_not_send_idempotency_key
    mock = Wajub::MockTransport.new([{ status: 200, body: { 'transactions' => [] } }])
    client = Wajub::BaseClient.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    client.get('/payments')

    assert_nil mock.last_request[:headers]['Idempotency-Key']
  end

  def test_get_passes_query_parameters
    mock = Wajub::MockTransport.new([{ status: 200, body: { 'transactions' => [], 'meta' => {} } }])
    client = Wajub::BaseClient.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    client.get('/payments', { 'page' => 2, 'status' => 'pending' })

    assert_equal({ 'page' => 2, 'status' => 'pending' }, mock.last_request[:query])
  end

  def test_raises_invalid_request_on_non_success_status
    mock = Wajub::MockTransport.new([
      { status: 422, body: { 'message' => 'Unprocessable', 'code' => 'validation_error' } }
    ])
    client = Wajub::BaseClient.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    error = assert_raises(Wajub::InvalidRequestError) { client.post('/payments', { 'amount' => -1 }) }
    assert_equal 'Unprocessable', error.message
  end
end
