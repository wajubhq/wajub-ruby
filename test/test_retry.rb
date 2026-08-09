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
end
