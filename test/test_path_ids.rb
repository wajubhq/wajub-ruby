# frozen_string_literal: true

require 'test_helper'

# The API reads an encoded "/" in a path as a separator, so an id holding one
# reached another route: payments.retrieve('pay_1/refunds') listed refunds and
# customers.delete('cus_1/tax_ids/txi_1') deleted a tax id. No Wajub id holds a
# "/": every method that puts an id in a path refuses one before sending.
class TestPathIds < Minitest::Test
  BAD = 'pay_1/refunds'

  def resources(mock)
    args = [API_KEY, Wajub::API_URL, 'wajub']
    crud = lambda do |path, singular, plural|
      Wajub::CrudResource.new(API_KEY, Wajub::API_URL, path, singular, plural, 'wajub', transport: mock)
    end
    {
      payments: Wajub::PaymentsResource.new(*args, transport: mock),
      events: Wajub::EventsResource.new(*args, transport: mock),
      customers: Wajub::CustomersResource.new(*args, transport: mock),
      accounts: Wajub::AccountsResource.new(*args, transport: mock),
      webhook_endpoints: Wajub::WebhookEndpointsResource.new(*args, transport: mock),
      invoices: Wajub::InvoicesResource.new(*args, transport: mock),
      disputes: Wajub::DisputesResource.new(*args, transport: mock),
      tax: Wajub::TaxResource.new(*args, transport: mock),
      shield: Wajub::ShieldResource.new(*args, transport: mock),
      refunds: crud.call('refunds', 'refund', 'refunds')
    }
  end

  def calls(id)
    [
      [:payments, :retrieve, [id]], [:payments, :cancel, [id]], [:payments, :process, [id, {}]],
      [:payments, :process_split, [id, {}]], [:payments, :list_refunds, [id]],
      [:events, :retrieve, [id]], [:events, :resend, [id]],
      [:customers, :retrieve, [id]], [:customers, :update, [id, {}]], [:customers, :delete, [id]],
      [:customers, :block, [id]], [:customers, :unblock, [id]], [:customers, :activate, [id]],
      [:customers, :deactivate, [id]], [:customers, :list_tax_ids, [id]], [:customers, :create_tax_id, [id, {}]],
      [:customers, :delete_tax_id, [id, 'txi_1']], [:customers, :delete_tax_id, ['cus_1', id]],
      [:accounts, :regenerate_token, [id]], [:webhook_endpoints, :rotate_secret, [id]],
      [:invoices, :send_invoice, [id]], [:invoices, :send, [id]], [:invoices, :mark_paid, [id]],
      [:invoices, :cancel, [id]],
      [:disputes, :retrieve, [id]], [:disputes, :submit_evidence, [id, {}]], [:disputes, :accept, [id]],
      [:disputes, :close, [id]], [:disputes, :send_message, [id, {}]],
      [:tax, :retrieve_code, [id]], [:tax, :retrieve_registration, [id]],
      [:tax, :update_registration, [id, {}]], [:tax, :delete_registration, [id]],
      [:shield, :remove_from_blocklist, [id]],
      [:refunds, :retrieve, [id]], [:refunds, :update, [id, {}]], [:refunds, :delete, [id]]
    ]
  end

  def test_an_id_with_a_slash_is_refused_before_anything_is_sent
    mock = Wajub::MockTransport.new([])
    all = resources(mock)

    calls(BAD).each do |resource, method, args|
      error = assert_raises(ArgumentError, "#{resource}.#{method}") do
        all.fetch(resource).public_send(method, *args)
      end
      assert_match(/must not contain "\/"/, error.message)
      assert_nil mock.last_request, "#{resource}.#{method} sent #{mock.last_request.inspect}"
    end
  end

  # An empty id left its segment out ("/payments/" is the list), and "." or ".."
  # are dot segments that servers and proxies resolve to another path.
  def test_an_empty_or_dot_id_is_refused_before_anything_is_sent
    mock = Wajub::MockTransport.new([])
    all = resources(mock)

    ['', '.', '..', nil].each do |id|
      calls(id).each do |resource, method, args|
        assert_raises(ArgumentError, "#{resource}.#{method}(#{id.inspect})") do
          all.fetch(resource).public_send(method, *args)
        end
        assert_nil mock.last_request, "#{resource}.#{method}(#{id.inspect}) sent #{mock.last_request.inspect}"
      end
    end
  end

  def test_a_nil_id_is_named_nil_in_the_error
    mock = Wajub::MockTransport.new([])

    error = assert_raises(ArgumentError) { resources(mock).fetch(:payments).retrieve(nil) }

    assert_match(/\bnil\b/, error.message)
    refute_includes error.message, '""'
  end

  # A space is %20 in a path: "+" is a literal plus there, not a space.
  def test_a_space_in_an_id_goes_out_as_percent_20
    mock = Wajub::MockTransport.new([])

    resources(mock).fetch(:payments).retrieve('a b+c')

    assert_equal '/payments/a%20b%2Bc', mock.last_request[:path]
  end

  def test_an_id_with_dots_inside_is_still_sent
    mock = Wajub::MockTransport.new([])

    resources(mock).fetch(:payments).retrieve('trx.1..2')

    assert_equal '/payments/trx.1..2', mock.last_request[:path]
  end

  def test_an_id_without_a_slash_is_still_sent_encoded
    mock = Wajub::MockTransport.new([])
    all = resources(mock)

    calls('a b?c').each do |resource, method, args|
      all.fetch(resource).public_send(method, *args)
      refute_nil mock.last_request, "#{resource}.#{method} sent nothing"
      refute_includes mock.last_request[:path], '?', "#{resource}.#{method}: #{mock.last_request[:path]}"
    end
  end
end
