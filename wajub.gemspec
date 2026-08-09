# frozen_string_literal: true

require_relative 'lib/wajub/version'

Gem::Specification.new do |spec|
  spec.name          = 'wajub'
  spec.version       = Wajub::VERSION
  spec.authors       = ['Wajub']
  spec.email         = ['hello@wajub.com']

  spec.summary       = 'Official Wajub Ruby SDK'
  spec.description   = 'Server-side Wajub payments, webhooks, and merchant API client.'
  spec.homepage      = 'https://docs.wajub.com/libraries/sdks/ruby'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/wajubhq/wajub-ruby'

  spec.files = Dir.chdir(__dir__) do
    Dir['lib/**/*.rb', 'README.md', 'LICENSE']
  end
  spec.require_paths = ['lib']
end
