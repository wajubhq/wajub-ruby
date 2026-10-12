# frozen_string_literal: true

module Wajub
  module RetryPolicy
    MAX_RETRIES = 2
    RETRYABLE = [429, 500, 502, 503, 504].freeze

    module_function

    def should_retry_status?(status)
      RETRYABLE.include?(status)
    end

    def max_retries
      MAX_RETRIES
    end

    # The 409 the API answers while a request with the same Idempotency-Key is
    # still running (errors.idempotency_key). A call sent again after a timeout
    # can arrive before the first has finished: its answer is on the way, so the
    # call is worth repeating with the same key. Every other 409 is a refusal.
    def idempotency_key_in_progress?(status, body)
      status == 409 && body.is_a?(Hash) && body['errors'].is_a?(Hash) && body['errors'].key?('idempotency_key')
    end

    # The pause before asking again about a key still being processed:
    # 2, 4, then 8 seconds.
    def idempotency_conflict_delay_seconds(attempt)
      2**[attempt, 1].max
    end

    def delay_seconds(attempt, response: nil)
      header = response&.[]('retry-after')&.strip
      if header && !header.empty?
        seconds = Integer(header, exception: false)
        return seconds if seconds

        time = Time.httpdate(header) rescue nil
        return [(time - Time.now).to_i, 0].max if time
      end

      0.5 * (2**(attempt - 1))
    end
  end
end
