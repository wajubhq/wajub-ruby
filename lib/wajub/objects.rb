# frozen_string_literal: true

module Wajub
  class ApiObject
    def initialize(data)
      @data = data.transform_keys(&:to_s)
    end

    def [](key)
      @data[key.to_s]
    end

    def to_h
      @data.dup
    end

    def method_missing(name, *args)
      return super if args.any? || name.end_with?('=')

      key = name.to_s
      return @data[key] if @data.key?(key)

      super
    end

    def respond_to_missing?(name, include_private = false)
      @data.key?(name.to_s) || super
    end
  end

  class Payment < ApiObject
    def id
      self['id']
    end

    def status
      self['status']
    end

    def authorization_url
      self['authorization_url']
    end

    def authorization_token
      self['authorization_token']
    end
  end
end
