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
end
