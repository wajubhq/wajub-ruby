# frozen_string_literal: true

require 'test_helper'

class TestRetry < Minitest::Test
  def test_retries_on_503_then_succeeds
    mock = Wajub::MockTransport.new([
      { status: 503, body: { 'message' => 'Unavailable' } },
      { status: 200, body: { 'ok' => true } }
    ])
    client = Wajub::GlobalResource.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    result = client.ping
    assert_equal true, result['ok']
    assert_equal 2, mock.instance_variable_get(:@index)
  end

  IN_PROGRESS = {
    'code' => 409,
    'status' => 'Conflict',
    'message' => 'A request with this Idempotency-Key is still being processed.',
    'errors' => { 'idempotency_key' => ['A request with this Idempotency-Key is still being processed.'] }
  }.freeze

  # A call sent again after a timeout can reach the API while the first one is
  # still running: the answer is on its way, so the client asks again.
  def test_asks_again_with_the_same_key_while_that_key_is_still_being_processed
    keys = []
    transport = Object.new
    responses = [{ status: 409, body: IN_PROGRESS }, { status: 201, body: { 'transaction' => { 'id' => 'trx_1' } } }]
    transport.define_singleton_method(:call) do |method:, path:, headers:, body:, query:|
      keys << headers['Idempotency-Key']
      responses.shift.merge(request: { method: method, path: path })
    end
    client = Wajub::BaseClient.new(API_KEY, Wajub::API_URL, 'wajub', transport: transport)
    sleeps = []
    client.define_singleton_method(:sleep) { |seconds| sleeps << seconds }

    result = client.post('/payments', { 'amount' => 1000 }, Wajub::RequestOptions.new(idempotency_key: 'ORDER-42'))

    assert_equal 'trx_1', result.dig('transaction', 'id')
    assert_equal %w[ORDER-42 ORDER-42], keys
    assert_equal [2], sleeps
  end

  def test_raises_any_other_409_at_once
    mock = Wajub::MockTransport.new([
      { status: 409, body: { 'code' => 409, 'error_code' => 'payment_in_progress', 'message' => 'A charge is already in progress.' } },
      { status: 200, body: { 'ok' => true } }
    ])
    client = Wajub::BaseClient.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)
    client.define_singleton_method(:sleep) { |_seconds| nil }

    assert_raises(Wajub::WajubError) { client.post('/payments/trx_1', { 'channel' => 'cm.mtn' }) }
    assert_equal 1, mock.instance_variable_get(:@index)
  end

  def test_waits_2_then_4_then_8_seconds_for_a_key_in_progress
    assert_equal [2, 4, 8], [1, 2, 3].map { |attempt| Wajub::RetryPolicy.idempotency_conflict_delay_seconds(attempt) }
  end
end
