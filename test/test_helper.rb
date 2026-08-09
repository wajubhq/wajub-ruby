# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'wajub'

API_KEY = 'sk_test.unit_test_key'

def with_env(vars)
  old = vars.keys.to_h { |key| [key, ENV[key]] }
  vars.each { |key, value| ENV[key] = value }
  yield
ensure
  old.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
end
