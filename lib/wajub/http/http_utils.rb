# frozen_string_literal: true

require 'securerandom'
require 'json'

module Wajub
  module HttpUtils
    module_function

    def normalize_api_key(raw)
      key = raw.to_s.strip
      key = key.sub(/\Abearer\s+/i, '').strip if key.match?(/\Abearer\s+/i)
      key
    end

    def api_url
      API_URL
    end

    def create_idempotency_key(prefix = 'wajub')
      "#{prefix}-#{SecureRandom.uuid}"
    end

    def pick_resource(body, *keys)
      keys.each do |key|
        return body[key] if body.key?(key) && !body[key].nil?
      end
      body
    end

    def pick_list(body, *keys)
      keys.each do |key|
        if body.key?(key) && !body[key].nil?
          return { data: body[key], meta: body['meta'] }
        end
      end
      if body.key?('items') && !body['items'].nil?
        return { data: body['items'], meta: body['meta'] }
      end
      { data: body['data'] || [], meta: body['meta'] }
    end

    def decode_json(data)
      JSON.parse(data)
    rescue JSON::ParserError
      {}
    end
  end
end
