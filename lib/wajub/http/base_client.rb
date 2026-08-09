# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

require_relative 'http_utils'
require_relative 'retry_policy'
require_relative '../errors'
require_relative '../request_options'
require_relative '../version'

module Wajub
  class BaseClient
    attr_reader :api_key, :base_url, :idempotency_key_prefix, :transport, :last_request

    def initialize(api_key, base_url, idempotency_key_prefix = 'wajub', transport: nil)
      @api_key = HttpUtils.normalize_api_key(api_key)
      @base_url = base_url.sub(%r{/+\z}, '')
      @idempotency_key_prefix = idempotency_key_prefix
      @transport = transport || NetHttpTransport.new(@base_url, user_agent: "wajub-ruby/#{VERSION}")
      @last_request = nil
    end

    def get(path, params = nil)
      request('GET', path, body: nil, options: nil, query: params)
    end

    def post(path, body = nil, options = nil)
      request('POST', path, body: body, options: options)
    end

    def put(path, body = nil, options = nil)
      request('PUT', path, body: body, options: options)
    end

    def delete(path, options = nil)
      request('DELETE', path, body: nil, options: options)
    end

    def request(method, path, body: nil, options: nil, query: nil)
      headers = {
        'Accept' => 'application/json',
        'Authorization' => @api_key
      }

      options ||= RequestOptions.new
      headers.merge!(options.headers) if options.headers
      headers['X-Sync'] = options.sync if options.sync

      idempotency_key = options.idempotency_key
      if idempotency_key.nil? && !%w[GET DELETE].include?(method)
        idempotency_key = HttpUtils.create_idempotency_key(@idempotency_key_prefix)
      end
      headers['Idempotency-Key'] = idempotency_key if idempotency_key

      payload = body.nil? ? nil : JSON.generate(body)
      headers['Content-Type'] = 'application/json' if payload

      attempt = 0

      loop do
        begin
          response = @transport.call(
            method: method,
            path: path,
            headers: headers,
            body: payload,
            query: query
          )
        rescue StandardError => e
          if attempt < RetryPolicy.max_retries
            attempt += 1
            sleep RetryPolicy.delay_seconds(attempt)
            next
          end
          raise ApiConnectionError.new(e.message)
        end

        @last_request = response[:request]
        status = response[:status]
        data = response[:body].is_a?(Hash) ? response[:body] : HttpUtils.decode_json(response[:body].to_s)

        return data if status >= 200 && status < 300

        if RetryPolicy.should_retry_status?(status) && attempt < RetryPolicy.max_retries
          attempt += 1
          sleep RetryPolicy.delay_seconds(attempt, response: response[:headers] || {})
          next
        end

        retry_after = response.dig(:headers, 'retry-after')&.to_i
        raise Errors.from_response(status, data, retry_after: retry_after)
      end
    end
  end

  class NetHttpTransport
    def initialize(base_url, user_agent:)
      @base_url = base_url
      @user_agent = user_agent
      @mutex = Mutex.new
    end

    def call(method:, path:, headers:, body:, query:)
      uri = URI.parse("#{@base_url}#{path}")
      if query
        filtered = query.compact
        uri.query = URI.encode_www_form(filtered) unless filtered.empty?
      end

      http = connection(uri)

      klass = Net::HTTP.const_get(method.capitalize)
      request = klass.new(uri)
      headers.each { |k, v| request[k] = v }
      request['User-Agent'] = @user_agent
      request.body = body if body

      response = http.request(request)
      {
        status: response.code.to_i,
        body: HttpUtils.decode_json(response.body),
        headers: response.to_hash.transform_values(&:first),
        request: {
          method: method,
          path: path,
          uri: uri.to_s,
          headers: headers.merge('User-Agent' => @user_agent)
        }
      }
    end

    private

    # Reuses a single keep-alive Net::HTTP connection across calls (instead of
    # opening a fresh TCP+TLS connection per request) since every call on this
    # transport targets the same host/port (derived from @base_url).
    def connection(uri)
      @mutex.synchronize do
        if @http && !@http.started?
          @http = nil
        end

        @http ||= begin
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.open_timeout = 30
          http.read_timeout = 30
          http.start
          http
        end
      end
    end
  end

  class MockTransport
    attr_reader :last_request

    def initialize(responses)
      @responses = responses
      @index = 0
      @last_request = nil
    end

    def call(method:, path:, headers:, body:, query:)
      @last_request = { method: method, path: path, headers: headers, body: body, query: query }
      response = @responses[@index] || { status: 200, body: {} }
      @index += 1
      response.merge(request: @last_request)
    end
  end
end
