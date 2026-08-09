# frozen_string_literal: true

module Wajub
  class RequestOptions
    attr_reader :idempotency_key, :headers, :sync

    def initialize(idempotency_key: nil, headers: nil, sync: nil)
      @idempotency_key = idempotency_key
      @headers = headers || {}
      @sync = sync
    end
  end
end
