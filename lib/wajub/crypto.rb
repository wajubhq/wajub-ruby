# frozen_string_literal: true

require 'openssl'

module Wajub
  module Crypto
    module_function

    def hmac_sha256(key, data)
      OpenSSL::HMAC.hexdigest('SHA256', key, data)
    end

    def timing_safe_equal(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack('C*')
      r = b.unpack('C*')
      result = 0
      l.zip(r) { |x, y| result |= x ^ y }
      result.zero?
    end
  end
end
