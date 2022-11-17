# frozen_string_literal: true

require_relative 'lib/ruby_http2/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby_http2'
  spec.version       = RubyHttp2::VERSION
  spec.authors       = ['']
  spec.email         = ['']

  spec.summary       = 'ruby_http2'
  spec.description   = 'ruby_http2'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Required for parsing http2 binary datastructures
  spec.add_runtime_dependency 'bindata'
  # Required for compressing the http2 header frame requests
  spec.add_runtime_dependency 'protocol-hpack'
  # Required for parsing addresses - the parser is more flexible than URI.parse, i.e.
  # `Addressable::URI.parse('http://user:p4@@w0rd@example.com').password` => p4@@w0rd
  # `::URI.parse('http://user:p4@@w0rd@example.com').password` => (URI::InvalidURIError)
  spec.add_runtime_dependency 'addressable'
end
