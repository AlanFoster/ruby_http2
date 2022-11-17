# frozen_string_literal: true

require 'protocol/hpack'
autoload :BinData, 'bindata'

module RubyHttp2
  module Protocol
    class Http2
      # Magic bytes required as confirmation of negotiating HTTP2
      # These bytes are sent immediately before the settings frame
      CONNECTION_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".b
      private_constant :CONNECTION_PREFACE

      # Class dedicated to handle http response headers,
      # as it's possibe for client/servers to send duplicate headers
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

      # the http2 binary model
      module Model
        # The currently supported http2 frame type codes
        # If the frame type is not supported, it is ignored as per the spec
        module FrameType
          DATA          = 0x00
          HEADERS       = 0x01
          PRIORITY      = 0x02
          RST_STREAM    = 0x03
          SETTINGS      = 0x04
          PUSH_PROMISE  = 0x05
          PING          = 0x06
          GOAWAY        = 0x07
          WINDOW_UPDATE = 0x08
          CONTINUATION  = 0x09
        end

        # The setting frame codes
        module SettingCode
          HEADER_TABLE_SIZE       = 0x1
          ENABLE_PUSH             = 0x2
          MAX_CONCURRENT_STREAMS  = 0x3
          INITIAL_WINDOW_SIZE     = 0x4
          MAX_FRAME_SIZE          = 0x5
          MAX_HEADER_LIST_SIZE    = 0x6
        end

        # The error codes used within a RST_STREAM or GOAWAY frame
        module ErrorCode
          NO_ERROR            = 0x00
          PROTOCOL_ERROR      = 0x01
          INTERNAL_ERROR      = 0x02
          FLOW_CONTROL_ERROR  = 0x03
          SETTINGS_TIMEOUT    = 0x04
          STREAM_CLOSED       = 0x05
          FRAME_SIZE_ERROR    = 0x06
          REFUSED_STREAM      = 0x07
          CANCEL              = 0x08
          COMPRESSION_ERROR   = 0x09
          CONNECT_ERROR       = 0x0a
          ENHANCE_YOUR_CALM   = 0x0b
          INADEQUATE_SECURITY = 0x0c
          HTTP_1_1_REQUIRED   = 0x0d
        end

        # Used to signify that the connection should shutdown, either gracefully
        # or to signify serious error scenarios
        class GoAwayFrame < BinData::Record
          endian :big

          # The length of the frame payload. The 9 octets of the frame header
          # are not included in this length
          # @!attribute [r] frame_length
          #   @return [Integer]
          uint24 :frame_length, initial_value: -> { settings.to_binary_s.length }

          # The frame type which determines the payload structure;
          # Unsupported frame types should be ignored
          # @!attribute [r] frame_type
          #   @return [Integer]
          uint8 :frame_type, initial_value: -> { FrameType::SETTINGS }

          # Boolean bit flag, the semantics depend on the frame type
          # @!attribute [r] flags
          #   @return [Integer]
          uint8 :flags

          bit1 :reserved1
          hide :reserved1

          # Specifies which stream the frame is associated with
          # Value 0x0 reserved for the connection as a whole
          # @!attribute [r] stream_identifier
          #   @return [Integer]
          bit31 :stream_identifier

          # The error code
          # @!attribute [r] error_code
          #   @return [Integer]
          # @see ErrorCode
          uint32 :error_code

          # The error data
          # @!attribute [r] data
          #   @return [String]
          string :data, read_length: -> { frame_length - 4 }
        end

        # The http2 settings frame used during the initial connection.
        # Contains arbitrary metadata such as initial window size, etc
        class SettingsFrame < BinData::Record
          endian :big

          # The length of the frame payload. The 9 octets of the frame header
          # are not included in this length
          # @!attribute [r] frame_length
          #   @return [Integer]
          uint24 :frame_length, initial_value: -> { settings.to_binary_s.length }

          # The frame type which determines the payload structure;
          # Unsupported frame types should be ignored
          # @!attribute [r] frame_type
          #   @return [Integer]
          uint8 :frame_type, initial_value: -> { FrameType::SETTINGS }

          # Boolean bit flag, the semantics depend on the frame type
          # @!attribute [r] flags
          #   @return [Integer]
          uint8 :flags

          bit1 :reserved
          hide :reserved

          # Specifies which stream the frame is associated with
          # Value 0x0 reserved for the connection as a whole
          # @!attribute [r] stream_identifier
          #   @return [Integer]
          bit31 :stream_identifier

          array :settings, initial_length: -> { frame_length / 5 } do
            # The settings identifier
            # @!attribute [r] identifier
            #   @return [Integer]
            uint16 :identifier

            # The setting value
            # @!attribute [r] flags
            #   @return [Integer]
            uint32 :setting_value
          end
        end

        # The headers frame, which can additionally contain a field block segment
        class HeadersFrame < BinData::Record
          endian :big

          hide :reserved1, :reserved2, :reserved3, :reserved4

          # The length of the frame payload. The 9 octets of the frame header
          # are not included in this length
          # @!attribute [r] frame_length
          #   @return [Integer]
          uint24 :frame_length, initial_value: -> { field_block_fragment.length }

          # The frame type which determines the payload structure;
          # Unsupported frame types should be ignored
          # @!attribute [r] frame_type
          #   @return [Integer]
          uint8 :frame_type, initial_value: -> { FrameType::HEADERS }

          #
          # Flags
          #

          bit2 :reserved1

          # When set, the exclusive/stream dependency/weight fields are present
          # @!attribute [r] priority
          #   @return [Integer]
          bit1 :priority
          bit1 :reserved2

          # When set, the pad length field and any padding that it describes is present
          # @!attribute [r] padded
          #   @return [Integer]
          bit1 :padded

          # When set, this frame is not followed any continuation frames
          # @!attribute [r] padded
          #   @return [Integer]
          bit1 :end_headers

          bit1 :reserved3

          # When set, it signifies that the field block is the lsat that the endpoint will
          # send for the identified stream
          # @!attribute [r] padded
          #   @return [Integer]
          bit1 :end_stream

          bit1 :reserved4

          # Specifies which stream the frame is associated with
          # Value 0x0 reserved for the connection as a whole
          # @!attribute [r] stream_identifier
          #   @return [Integer]
          bit31 :stream_identifier

          # The pad length
          # @!attribute [r] pad_length
          #   @return [Integer]
          uint8 :pad_length, onlyif: -> { padded == 1 }

          # Deprecated; Do not use
          # @!attribute [r] exclusive
          #   @return [Integer]
          bit1 :exclusive, onlyif: -> { priority == 1 }

          # If priority bit is set, this is a stream identifier
          # @!attribute [r] stream_dependency
          #   @return [Integer]
          bit31 :stream_dependency, onlyif: -> { priority == 1 }

          # If priority bit is set, this is the weight
          # @!attribute [r] weight
          #   @return [Integer]
          uint8 :weight, onlyif: -> { priority == 1 }

          # Compressed HPACK binary blob
          # @!attribute [r] field_block_fragment
          #   @return [String]
          string :field_block_fragment, read_length: -> { frame_length }

          string :padding, length: :pad_length

          # @return [Array<Array<String>>] The http headers, for example `[['content-length', '5']]`
          def headers
            decompressor = ::Protocol::HPACK::Decompressor.new(self.field_block_fragment)
            decompressor.decode
          end

          # @param [Array<Array<String>>] headers The http headers, for example `[['content-length', '5']]`
          def headers=(headers)
            buffer = String.new.b
            compressor = ::Protocol::HPACK::Compressor.new(buffer)
            compressor.encode(headers)

            self.field_block_fragment = buffer
          end
        end

        # Window update frame
        class WindowUpdateFrame < BinData::Record
          endian :big

          # The length of the frame payload. The 9 octets of the frame header
          # are not included in this length
          # @!attribute [r] frame_length
          #   @return [Integer]
          uint24 :frame_length, assert_value: -> { 4 }

          # The frame type which determines the payload structure;
          # Unsupported frame types should be ignored
          # @!attribute [r] frame_type
          #   @return [Integer]
          uint8 :frame_type, initial_value: -> { FrameType::WINDOW_UPDATE }

          # Boolean bit flag, the semantics depend on the frame type
          # @!attribute [r] flags
          #   @return [Integer]
          uint8 :flags

          bit1 :reserved1
          hide :reserved1

          # Specifies which stream the frame is associated with
          # Value 0x0 reserved for the connection as a whole
          # @!attribute [r] stream_identifier
          #   @return [Integer]
          bit31 :stream_identifier

          bit1 :reserved2
          hide :reserved2

          # The window size increment
          # @!attribute [r] window_size_increment
          #   @return [Integer]
          bit31 :window_size_increment
        end

        # An opaque http2 frame sent to/from the client/server; There is a dedicated frame
        # object for each frame which will be reparsed once a frame type is successfully
        # identified.s
        class OpaqueFrame < BinData::Record
          endian :big

          # The length of the frame payload. The 9 octets of the frame header
          # are not included in this length
          # @!attribute [r] frame_length
          #   @return [Integer]
          uint24 :frame_length, initial_value: -> { payload.to_binary_s.length }

          # The frame type which determines the payload structure;
          # Unsupported frame types should be ignored
          # @!attribute [r] frame_type
          #   @return [Integer]
          uint8 :frame_type

          # Boolean bit flag, the semantics depend on the frame type
          # @!attribute [r] flags
          #   @return [Integer]
          uint8 :flags

          bit1 :reserved
          hide :reserved

          # Specifies which stream the frame is associated with
          # Value 0x0 reserved for the connection as a whole
          # @!attribute [r] stream_identifier
          #   @return [Integer]
          bit31 :stream_identifier

          string :data, read_length: :frame_length
        end
      end

      # @param [Socket] socket
      # @param [String] path
      # @param [Array<String>] headers Example: ["Host: example.com"]
      # @return [Response] The http response
      def get(socket, path, headers: [])
        socket.write_nonblock(CONNECTION_PREFACE)

        settings = Model::SettingsFrame.new(
          settings: [
            {
              identifier: Model::SettingCode::MAX_CONCURRENT_STREAMS,
              setting_value: 100
            },
            {
              identifier: Model::SettingCode::INITIAL_WINDOW_SIZE,
              setting_value: 1073741824
            },
            {
              identifier: Model::SettingCode::ENABLE_PUSH,
              # A server MUST NOT send a PUSH_PROMISE frame if it receives this parameter set to a value of 0
              setting_value: 0
            },
          ]
        )

        socket.write_nonblock(settings.to_binary_s)

        get_request = Model::HeadersFrame.new(
          priority: 0,
          padded: 0,
          end_headers: 1,
          end_stream: 1,
          stream_identifier: 1,
        )

        # https://www.rfc-editor.org/rfc/rfc9113.html#section-8.3.1
        pseudo_request_headers = [
          %w[:method GET],
          [":path", path],
          %w[:scheme https],
          %w[:authority example.com],
        ]
        get_request.headers = pseudo_request_headers + headers.map { |k, v| [k.downcase, v] }
        socket.write_nonblock(get_request.to_binary_s)

        nil
      end

      protected

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
