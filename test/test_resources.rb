# frozen_string_literal: true

require 'test_helper'

class TestResources < Minitest::Test
  def test_payments_create_unwraps_transaction_and_urls
    mock = Wajub::MockTransport.new([
      {
        status: 200,
        body: {
          'transaction' => { 'id' => 'pay_123', 'status' => 'pending' },
          'authorization_token' => 'tok_abc',
          'authorization_url' => 'https://checkout.test/pay/pay_123'
        }
      }
    ])
    payments = Wajub::PaymentsResource.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    payment = payments.create('amount' => 5000, 'currency' => 'XAF')

    assert_instance_of Wajub::Payment, payment
    assert_equal 'pay_123', payment.id
    assert_equal 'tok_abc', payment.authorization_token
    assert_equal 'https://checkout.test/pay/pay_123', payment.authorization_url
    assert_equal 'pay_123', payment['id']
  end

  def test_payments_list_pagination
    mock = Wajub::MockTransport.new([
      {
        status: 200,
        body: {
          'transactions' => [{ 'id' => 'pay_1' }],
          'meta' => { 'current_page' => 1, 'last_page' => 2 }
        }
      },
      {
        status: 200,
        body: {
          'transactions' => [{ 'id' => 'pay_2' }],
          'meta' => { 'current_page' => 2, 'last_page' => 2 }
        }
      }
    ])
    payments = Wajub::PaymentsResource.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    page1 = payments.list('per_page' => 1)
    assert_equal 'pay_1', page1.data.first['id']
    assert page1.has_more

    page2 = page1.next_page
    assert_equal 'pay_2', page2.data.first['id']
    refute page2.has_more
  end

  def test_payments_list_falls_back_to_items_key
    mock = Wajub::MockTransport.new([
      {
        status: 200,
        body: {
          'items' => [{ 'id' => 'pay_1' }],
          'meta' => { 'current_page' => 1, 'last_page' => 1 }
        }
      }
    ])
    payments = Wajub::PaymentsResource.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    page = payments.list
    assert_equal 'pay_1', page.data.first['id']
  end

  def test_refunds_crud
    mock = Wajub::MockTransport.new([
      { status: 200, body: { 'refund' => { 'id' => 'ref_new' } } },
      { status: 200, body: { 'refund' => { 'id' => 'ref_new', 'status' => 'pending' } } },
      { status: 200, body: {} }
    ])
    refunds = Wajub::CrudResource.new(API_KEY, Wajub::API_URL, 'refunds', 'refund', 'refunds', 'wajub', transport: mock)

    created = refunds.create('payment_id' => 'pay_1', 'amount' => 500)
    assert_equal 'ref_new', created['id']

    retrieved = refunds.retrieve('ref_new')
    assert_equal 'pending', retrieved['status']

    refunds.delete('ref_new')
    assert_equal 'DELETE', mock.last_request[:method]
  end

  # delete_tax_id went through CrudResource#delete, which takes an id: the whole
  # path was encoded as one and the call hit DELETE /customers/%2Fcustomers%2F...
  def test_customers_delete_tax_id_calls_the_nested_path
    mock = Wajub::MockTransport.new([{ status: 200, body: {} }])
    customers = Wajub::CustomersResource.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    customers.delete_tax_id('cus_1', 'txi/2', Wajub::RequestOptions.new(idempotency_key: 'del-1'))

    assert_equal 'DELETE', mock.last_request[:method]
    assert_equal '/customers/cus_1/tax_ids/txi%2F2', mock.last_request[:path]
    assert_equal 'del-1', mock.last_request[:headers]['Idempotency-Key']
  end

  def test_customers_delete_still_encodes_the_id
    mock = Wajub::MockTransport.new([{ status: 200, body: {} }])
    customers = Wajub::CustomersResource.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)

    customers.delete('cus/1')

    assert_equal '/customers/cus%2F1', mock.last_request[:path]
  end

  def invoices_with(mock)
    Wajub::InvoicesResource.new(API_KEY, Wajub::API_URL, 'wajub', transport: mock)
  end

  def test_invoices_send_invoice_sends_the_invoice
    mock = Wajub::MockTransport.new([{ status: 200, body: { 'invoice' => { 'id' => 'inv_1', 'status' => 'sent' } } }])

    invoice = invoices_with(mock).send_invoice('inv/1', Wajub::RequestOptions.new(idempotency_key: 'send-1'))

    assert_equal 'sent', invoice['status']
    assert_equal 'POST', mock.last_request[:method]
    assert_equal '/invoices/inv%2F1/send', mock.last_request[:path]
    assert_equal 'send-1', mock.last_request[:headers]['Idempotency-Key']
  end

  def test_invoices_send_with_an_id_still_sends_the_invoice
    mock = Wajub::MockTransport.new([{ status: 200, body: { 'invoice' => { 'id' => 'inv_1', 'status' => 'sent' } } }])

    invoice = invoices_with(mock).send('inv_1', Wajub::RequestOptions.new(idempotency_key: 'send-2'))

    assert_equal 'sent', invoice['status']
    assert_equal '/invoices/inv_1/send', mock.last_request[:path]
    assert_equal 'send-2', mock.last_request[:headers]['Idempotency-Key']
  end

  # InvoicesResource#send hid Object#send: send(:retrieve, 'inv_1'), as code
  # that calls a method by name does, sent the invoice with id "retrieve".
  def test_invoices_send_with_a_symbol_calls_that_method
    mock = Wajub::MockTransport.new([
      { status: 200, body: { 'invoice' => { 'id' => 'inv_1', 'status' => 'draft' } } },
      { status: 200, body: { 'invoice' => { 'id' => 'inv_3', 'status' => 'sent' } } }
    ])
    invoices = invoices_with(mock)

    assert_equal 'inv_1', invoices.send(:retrieve, 'inv_1')['id']
    assert_equal 'GET', mock.last_request[:method]
    assert_equal '/invoices/inv_1', mock.last_request[:path]

    assert_equal 'sent', invoices.send(:send_invoice, 'inv_3')['status']
    assert_equal '/invoices/inv_3/send', mock.last_request[:path]

    assert_equal 'Wajub::InvoicesResource', invoices.send(:class).name
    assert invoices.send(:respond_to?, :send_invoice)
  end

  # A String is always an invoice id, even one that names a method: an id from
  # a request, such as invoices.send(params[:id]), never calls a method.
  def test_invoices_send_with_a_string_always_sends_that_invoice
    names = %w[exit api_key freeze inspect list retrieve]
    mock = Wajub::MockTransport.new(names.map { |name| { status: 200, body: { 'invoice' => { 'id' => name, 'status' => 'sent' } } } })
    invoices = invoices_with(mock)

    names.each do |name|
      begin
        invoice = invoices.send(name)
      rescue SystemExit
        flunk "send(#{name.inspect}) called Kernel#exit"
      end

      assert_kind_of Hash, invoice, "send(#{name.inspect}) returned #{invoice.inspect}"
      assert_equal 'sent', invoice['status']
      assert_equal 'POST', mock.last_request[:method]
      assert_equal "/invoices/#{name}/send", mock.last_request[:path]
    end
    refute_predicate invoices, :frozen?
  end
end
