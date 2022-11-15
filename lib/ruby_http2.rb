# frozen_string_literal: true

require 'ruby_http2/version'

module RubyHttp2
  class Error < StandardError; end

  autoload :Client, 'ruby_http2/client'
  autoload :Protocol, 'ruby_http2/protocol'
end
