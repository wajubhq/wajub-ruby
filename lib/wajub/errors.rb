# frozen_string_literal: true

module Wajub
  class WajubError < StandardError
    attr_reader :code, :http_status, :errors, :raw

    def initialize(message, code:, http_status:, errors: nil, raw: nil)
      super(message)
      @code = code
      @http_status = http_status
      @errors = errors
      @raw = raw
    end
  end

  class AuthenticationError < WajubError; end
  class PermissionError < WajubError; end
  class NotFoundError < WajubError; end
  class InvalidRequestError < WajubError; end

  class RateLimitError < WajubError
    attr_reader :retry_after

    def initialize(message, code:, http_status:, errors: nil, raw: nil, retry_after: nil)
      super(message, code: code, http_status: http_status, errors: errors, raw: raw)
      @retry_after = retry_after
    end
  end

  class ApiConnectionError < WajubError
    def initialize(message, code: 'network_error', http_status: 0, errors: nil, raw: nil)
      super(message, code: code, http_status: http_status, errors: errors, raw: raw)
    end
  end

  class WebhookSignatureVerificationError < StandardError; end

  module Errors
    module_function

    def from_response(status, body, retry_after: nil)
      message = body['message'] || "Request failed (#{status})"
      code = body['error_code'] || body['code'] || "http_#{status}"
      field_errors = parse_field_errors(body['errors'])

      case status
      when 401 then AuthenticationError.new(message, code: code, http_status: status, errors: field_errors, raw: body)
      when 403 then PermissionError.new(message, code: code, http_status: status, errors: field_errors, raw: body)
      when 404 then NotFoundError.new(message, code: code, http_status: status, errors: field_errors, raw: body)
      when 429 then RateLimitError.new(message, code: code, http_status: status, errors: field_errors, raw: body, retry_after: retry_after)
      when 400, 422 then InvalidRequestError.new(message, code: code, http_status: status, errors: field_errors, raw: body)
      else WajubError.new(message, code: code, http_status: status, errors: field_errors, raw: body)
      end
    end

    def parse_field_errors(raw)
      return nil unless raw.is_a?(Hash)

      raw.transform_values do |value|
        value.is_a?(Array) ? value.first.to_s : value.to_s
      end
    end
  end
end
