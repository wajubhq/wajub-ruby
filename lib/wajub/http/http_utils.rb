# frozen_string_literal: true

require 'securerandom'
require 'json'
require 'uri'

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

    # An id as one segment of a request path. The API reads an encoded "/" as
    # a separator, an empty id leaves its segment out, and "." or ".." are dot
    # segments that servers resolve: such an id would reach another route. No
    # Wajub id takes these forms, so it is refused before anything is sent.
    def path_segment(id)
      raise ArgumentError, 'Wajub: an id is required (got nil)' if id.nil?

      value = id.to_s
      raise ArgumentError, "Wajub: an id must not contain \"/\" (got #{value.inspect})" if value.include?('/')
      raise ArgumentError, "Wajub: #{value.inspect} is not a Wajub id" if ['', '.', '..'].include?(value)

      # Form encoding writes a space as "+", which a path reads as a plus sign;
      # it writes a "+" as %2B, so every "+" left is a space.
      URI.encode_www_form_component(value).gsub('+', '%20')
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
