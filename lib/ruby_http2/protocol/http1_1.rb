# frozen_string_literal: true

autoload :Logger, 'logger'

module RubyHttp2
  module Protocol
    class Http1_1
      # The HTTP separator for HTTP/1.1 responses
      CRLF = "\r\n".b
      private_constant :CRLF

      # Class dedicated to handle http response headers,
      # as it's possible for client/servers to send duplicate headers
      # with identical names/case sensitivity overlaps etc
      class ResponseHeaders
        # @param [Array<String>] headers
        def initialize(headers: [])
          @headers = headers
        end

        # @param [Array<String>] header The tuple string of key value
        def <<(header)
          @headers << header
          self
        end

        # Perform a case insensitive lookup of the response headers
        # @param [String] key The header key to search for
        # @return [String,nil] The header value, or nil
        def [](key)
          @headers.find { |header_key, _header_value| header_key.casecmp?(key) }&.last
        end

        def to_a
          @headers.dup
        end
      end

      class Response
        attr_reader :status, :status_text, :headers, :body

        # @param [Numeric] status The http status code
        # @param [nil] status_text the returned http status text
        # @param [Array<String>] headers The http headers returned; Not a map to allow duplicate fields
        # @param [String,nil] body The http response body - if any
        def initialize(
          status: nil,
          status_text: nil,
          headers: [],
          body: nil
        )
          @status = status
          @status_text = status_text
          @headers = headers
          @body = body
        end
      end

      # @param [Logger] logger
      def initialize(
        logger: Logger.new(nil)
      )
        @logger = logger
      end

      # @param [Socket] socket
      # @param [::Addressable::URL] url The url to request
      # @param [Array<String>] headers Example: ["Host: example.com"]
      # @return [Response] The http response
      def get(socket, url, headers: [])
        request = +"".b

        request << "GET #{url.normalized_path} HTTP/1.1#{CRLF}"
        headers.each do |key, value|
          request << "#{key}: #{value}#{CRLF}"
        end
        request << CRLF

        logger.debug("request: #{request.inspect}")
        socket.write(request)

        parse_response(socket)
      end

      protected

      # @return [Logger] The logger
      attr_reader :logger

      # Reads a full http  response from the given socket
      # including status line, headers, and body
      #
      # @param [Socket] socket
      # @return [RubyHttp2::Protocol::Http1_1::Response]
      def parse_response(socket)
        buffer = +''.b
        line, buffer = read_line(buffer, socket)

        status, status_text = parse_status(line)
        headers = ResponseHeaders.new
        while (header_line, buffer = read_line(buffer, socket))
          break if header_line.empty?

          headers << parse_header(header_line)
        end

        content_length = headers['Content-Length']
        body = ''.b
        if content_length
          content_length = content_length.to_i
          # Append left over contents from parsing the header
          body << buffer
          body << socket.read(content_length - buffer.length) until body.length >= content_length.to_i
        end

        Response.new(
          status: status,
          status_text: status_text,
          body: body,
          headers: headers
        )
      end

      # @param [String] line
      # @return [Array<Numeric, String>] Tuple of status and status_text
      def parse_status(line)
        match = %r{^HTTP/1.\d+ (?<status>\d+) (?<status_text>.*)$}.match(line)
        [match[:status].to_i, match[:status_text]]
      end

      # @param [String] line
      # @return [Array<String>] Tuple of header name and value
      def parse_header(line)
        key, value = line.split(': ', 2)
        [key, value]
      end

      # @param [String] buffer the unparsed buffer so far
      # @param [Socket] socket
      # @return [Array<String>] The first element is the line, the rest is the remaining buffer
      def read_line(buffer, socket)
        buffer << socket.read(1024) until buffer.include?(CRLF)

        line, remaining = buffer.split(CRLF, 2)
        [line, remaining]
      end
    end
  end
end
