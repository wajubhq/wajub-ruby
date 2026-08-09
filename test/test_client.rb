# frozen_string_literal: true

require 'test_helper'

class TestClient < Minitest::Test
  def test_requires_api_key
    assert_raises(ArgumentError, /api_key is required/) { Wajub::Client.new(api_key: '') }
  end

  def test_reads_api_key_from_environment
    with_env('WAJUB_API_KEY' => API_KEY) do
      client = Wajub::Client.new
      assert_equal API_KEY, client.payments.api_key
    end
  end

  def test_exposes_all_resources
    client = Wajub::Client.new(api_key: API_KEY)
    %i[global payments customers refunds transfers beneficiaries links balance events
       accounts webhook_endpoints invoices disputes identity tax shield listen webhooks].each do |name|
      assert client.public_send(name), "missing #{name}"
    end
  end

  def test_webhook_secret_from_environment
    with_env('WAJUB_API_KEY' => API_KEY, 'WAJUB_WEBHOOK_SECRET' => 'whsec_test') do
      client = Wajub::Client.new
      assert_equal 'whsec_test', client.webhooks.secret
    end
  end
end
