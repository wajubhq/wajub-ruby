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
