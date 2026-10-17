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

  # errors keeps the first message of each field; field_errors keeps them all.
  def test_invalid_request_keeps_every_message_of_a_field
    mock = Wajub::MockTransport.new([
      {
        status: 422,
        body: {
          'message' => 'The given data was invalid.',
          'errors' => {
            'amount' => ['The amount must be a number.', 'The amount must be at least 1.'],
            'currency' => ['The currency field is required.'],
            'email' => 'The email must be a valid email address.'
          }
        }
      }
    ])
    client = Wajub::BaseClient.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    error = assert_raises(Wajub::InvalidRequestError) { client.post('/payments', { 'amount' => 'x' }) }

    assert_equal({
                   'amount' => ['The amount must be a number.', 'The amount must be at least 1.'],
                   'currency' => ['The currency field is required.'],
                   'email' => ['The email must be a valid email address.']
                 }, error.field_errors)
    assert_equal({
                   'amount' => 'The amount must be a number.',
                   'currency' => 'The currency field is required.',
                   'email' => 'The email must be a valid email address.'
                 }, error.errors)
  end

  def test_an_error_without_field_messages_has_no_field_errors
    mock = Wajub::MockTransport.new([{ status: 404, body: { 'message' => 'Not found' } }])
    client = Wajub::BaseClient.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    error = assert_raises(Wajub::NotFoundError) { client.get('/payments/pay_x') }

    assert_nil error.errors
    assert_nil error.field_errors
  end

  def test_an_error_built_with_errors_alone_lists_them_in_field_errors
    error = Wajub::InvalidRequestError.new('Invalid', code: 'validation_error', http_status: 422,
                                                      errors: { 'amount' => 'Must be positive' })

    assert_equal({ 'amount' => ['Must be positive'] }, error.field_errors)
  end

  # Built by hand, as 1.3.0 allowed: errors that are not a Hash are kept as
  # they are, and field_errors stays empty.
  def test_an_error_built_with_errors_that_are_not_a_hash_still_builds
    error = Wajub::InvalidRequestError.new('Invalid', code: 'validation_error', http_status: 422, errors: ['msg'])

    assert_equal ['msg'], error.errors
    assert_nil error.field_errors
  end

  # Built by hand, a value that is not a list is one message, whatever it is.
  def test_an_error_built_with_nil_or_hash_values_keeps_each_as_one_message
    error = Wajub::InvalidRequestError.new('Invalid', code: 'validation_error', http_status: 422,
                                                      errors: { 'amount' => nil, 'address' => { 'city' => 'required' } })

    assert_equal({ 'amount' => [nil], 'address' => [{ 'city' => 'required' }] }, error.field_errors)
  end

  def test_an_error_built_with_lists_of_messages_keeps_them_in_field_errors
    error = Wajub::InvalidRequestError.new('Invalid', code: 'validation_error', http_status: 422,
                                                      errors: { 'amount' => %w[a b] })

    assert_equal({ 'amount' => %w[a b] }, error.field_errors)
  end
end
