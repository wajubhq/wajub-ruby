# frozen_string_literal: true

module Wajub
  class WajubError < StandardError
    # errors holds the first message of each field; field_errors holds every
    # message of each field, as an Array, in the order the API sent them.
    attr_reader :code, :http_status, :errors, :field_errors, :raw

    def initialize(message, code:, http_status:, errors: nil, raw: nil, field_errors: nil)
      super(message)
      @code = code
      @http_status = http_status
      @errors = errors
      @field_errors = field_errors || (errors.transform_values { |value| value.is_a?(Array) ? value : [value] } if errors.is_a?(Hash))
      @raw = raw
    end
  end

  class AuthenticationError < WajubError; end
  class PermissionError < WajubError; end
  class NotFoundError < WajubError; end
  class InvalidRequestError < WajubError; end

  class RateLimitError < WajubError
    attr_reader :retry_after

    def initialize(message, code:, http_status:, errors: nil, raw: nil, retry_after: nil, field_errors: nil)
      super(message, code: code, http_status: http_status, errors: errors, raw: raw, field_errors: field_errors)
      @retry_after = retry_after
    end
  end

  class ApiConnectionError < WajubError
    def initialize(message, code: 'network_error', http_status: 0, errors: nil, raw: nil, field_errors: nil)
      super(message, code: code, http_status: http_status, errors: errors, raw: raw, field_errors: field_errors)
    end
  end

  class WebhookSignatureVerificationError < StandardError; end

  module Errors
    module_function

    def from_response(status, body, retry_after: nil)
      message = body['message'] || "Request failed (#{status})"
      code = body['error_code'] || body['code'] || "http_#{status}"
      details = {
        code: code,
        http_status: status,
        errors: parse_field_errors(body['errors']),
        field_errors: parse_all_field_errors(body['errors']),
        raw: body
      }

      case status
      when 401 then AuthenticationError.new(message, **details)
      when 403 then PermissionError.new(message, **details)
      when 404 then NotFoundError.new(message, **details)
      when 429 then RateLimitError.new(message, **details, retry_after: retry_after)
      when 400, 422 then InvalidRequestError.new(message, **details)
      else WajubError.new(message, **details)
      end
    end

    def parse_field_errors(raw)
      return nil unless raw.is_a?(Hash)

      raw.transform_values do |value|
        value.is_a?(Array) ? value.first.to_s : value.to_s
      end
    end

    def parse_all_field_errors(raw)
      return nil unless raw.is_a?(Hash)

      raw.transform_values do |value|
        value.is_a?(Array) ? value.map(&:to_s) : [value.to_s]
      end
    end
  end
end
