# frozen_string_literal: true

module RubyHttp2
  module Protocol
    autoload :Http1_1, 'ruby_http2/protocol/http1_1'
    autoload :Http2, 'ruby_http2/protocol/http2'
  end
end
