# frozen_string_literal: true

require 'test_helper'

# The tax and shield methods the other SDKs have, with the same paths and the
# same response keys as the Python SDK.
class TestTaxShield < Minitest::Test
  # Answers each call with the next body, and keeps every request.
  class RecordingTransport
    attr_reader :requests

    def initialize(bodies)
      @bodies = bodies
      @requests = []
    end

    def call(method:, path:, headers:, body:, query:)
      request = { method: method, path: path, headers: headers, body: body, query: query }
      @requests << request
      { status: 200, body: @bodies.shift || {}, request: request }
    end
  end

  def tax(*bodies)
    @transport = RecordingTransport.new(bodies)
    Wajub::TaxResource.new(API_KEY, Wajub::API_URL, 'wajub', transport: @transport)
  end

  def shield(*bodies)
    @transport = RecordingTransport.new(bodies)
    Wajub::ShieldResource.new(API_KEY, Wajub::API_URL, 'wajub', transport: @transport)
  end

  def last
    @transport.requests.last
  end

  def test_reports_reads_the_reports_list_with_its_query
    data, meta = tax({ 'reports' => [{ 'period' => '30d' }], 'meta' => { 'total' => 1 } }).reports('period' => '30d')

    assert_equal [{ 'period' => '30d' }], data
    assert_equal({ 'total' => 1 }, meta)
    assert_equal ['GET', '/tax/reports', { 'period' => '30d' }], last.values_at(:method, :path, :query)
  end

  def test_list_codes_reads_tax_codes
    data, = tax({ 'tax_codes' => [{ 'code' => 'txcd_1' }] }).list_codes('search' => 'food')

    assert_equal [{ 'code' => 'txcd_1' }], data
    assert_equal ['GET', '/tax/codes', { 'search' => 'food' }], last.values_at(:method, :path, :query)
  end

  def test_retrieve_code_unwraps_tax_code_and_encodes_the_code
    code = tax({ 'tax_code' => { 'code' => 'txcd?1' } }).retrieve_code('txcd?1')

    assert_equal({ 'code' => 'txcd?1' }, code)
    assert_equal ['GET', '/tax/codes/txcd%3F1'], last.values_at(:method, :path)
  end

  def test_list_registrations_is_a_page
    page = tax({ 'registrations' => [{ 'id' => 'reg_1' }], 'total' => 1 }).list_registrations

    assert_instance_of Wajub::PagedResult, page
    assert_equal [{ 'id' => 'reg_1' }], page.data
    refute page.has_more
    assert_equal ['GET', '/tax/registrations'], last.values_at(:method, :path)
  end

  def test_create_registration_posts_with_an_idempotency_key
    params = { 'country_code' => 'CM', 'registration_number' => 'M123' }
    registration = tax({ 'registration' => { 'id' => 'reg_1' } }).create_registration(params)

    assert_equal({ 'id' => 'reg_1' }, registration)
    assert_equal ['POST', '/tax/registrations'], last.values_at(:method, :path)
    assert_equal params, JSON.parse(last[:body])
    assert last[:headers]['Idempotency-Key']
  end

  def test_retrieve_update_and_delete_registration
    resource = tax({ 'registration' => { 'id' => 'reg_1' } }, { 'registration' => { 'id' => 'reg_1', 'active' => false } }, {})

    assert_equal({ 'id' => 'reg_1' }, resource.retrieve_registration('reg_1'))
    assert_equal ['GET', '/tax/registrations/reg_1'], last.values_at(:method, :path)

    updated = resource.update_registration('reg_1', { 'active' => false }, Wajub::RequestOptions.new(idempotency_key: 'upd-1'))
    assert_equal false, updated['active']
    assert_equal ['PUT', '/tax/registrations/reg_1', 'upd-1'], [last[:method], last[:path], last[:headers]['Idempotency-Key']]

    resource.delete_registration('reg_1')
    assert_equal ['DELETE', '/tax/registrations/reg_1'], last.values_at(:method, :path)
  end

  def test_jurisdictions_thresholds_and_alerts
    resource = tax(
      { 'jurisdictions' => [{ 'country_code' => 'CM' }] },
      { 'thresholds' => [{ 'country_code' => 'NG' }] },
      { 'alerts' => [{ 'country_code' => 'KE' }] }
    )

    assert_equal [{ 'country_code' => 'CM' }], resource.jurisdictions('country' => 'CM').first
    assert_equal ['/tax/jurisdictions', { 'country' => 'CM' }], last.values_at(:path, :query)
    assert_equal [{ 'country_code' => 'NG' }], resource.thresholds.first
    assert_equal '/tax/thresholds', last[:path]
    assert_equal [{ 'country_code' => 'KE' }], resource.threshold_alerts.first
    assert_equal '/tax/thresholds/alerts', last[:path]
  end

  def test_list_blocklist_reads_the_blocklist
    data, = shield({ 'blocklist' => [{ 'id' => 'blk_1', 'type' => 'phone' }] }).list_blocklist('type' => 'phone')

    assert_equal [{ 'id' => 'blk_1', 'type' => 'phone' }], data
    assert_equal ['GET', '/shield/blocklist', { 'type' => 'phone' }], last.values_at(:method, :path, :query)
  end

  def test_add_to_blocklist_posts_with_an_idempotency_key
    params = { 'type' => 'phone', 'value' => '+237670000000' }
    result = shield({ 'blocklist' => [{ 'id' => 'blk_1' }] }).add_to_blocklist(params)

    assert_equal [{ 'id' => 'blk_1' }], result
    assert_equal ['POST', '/shield/blocklist'], last.values_at(:method, :path)
    assert_equal params, JSON.parse(last[:body])
    assert last[:headers]['Idempotency-Key']
  end

  def test_remove_from_blocklist_deletes_the_entry
    shield({}).remove_from_blocklist('blk?1', Wajub::RequestOptions.new(idempotency_key: 'rm-1'))

    assert_equal ['DELETE', '/shield/blocklist/blk%3F1', 'rm-1'], [last[:method], last[:path], last[:headers]['Idempotency-Key']]
  end
end
