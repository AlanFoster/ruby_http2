# frozen_string_literal: true

autoload :Socket, 'socket'
autoload :Addrinfo, 'socket'
autoload :Logger, 'logger'
autoload :OpenSSL, 'openssl'

module RubyHttp2
  class Client
    # @param [String] host
    # @param [Numeric] port
    # @param [Array<Symbol>] protocols The protocols to negotiate, i.e. http1_1 or http2
    # @param [Boolean] ssl
    # @param [Socket] socket
    # @param [String,nil] sslkeylogfile The SSLKEYLOGFILE path
    # @param [Logger] logger
    # @return [RubyHttp2::Client]
    def initialize(
      host: nil,
      port: nil,
      protocols: nil,
      ssl: false,
      socket: nil,
      sslkeylogfile: nil,
      logger: Logger.new(nil)
    )
      @host = host
      @port = port
      @protocols = protocols
      @ssl = ssl
      @socket = socket
      @sslkeylogfile = sslkeylogfile
      @logger = logger
    end

    # @param [String] path The path, i.e /foo.html
    # @param [Array<String>] headers The HTTP headers to send
    def get(path, headers: [])
      socket = negotiate

      if negotiated_protocol == :http1_1
        Protocol::Http1_1.new.get(@ssl ? ssl_socket : socket, path, headers: headers)
      elsif negotiated_protocol == :http2
        Protocol::Http2.new.get(ssl_socket, path, headers: headers)
      else
        raise "unsupported protocol #{negotiated_protocol}"
      end
    end

    protected

    # @return [Logger] The logger
    attr_reader :logger

    # @return [OpenSSL::SSL::Session]
    attr_reader :ssl_socket

    def negotiate
      socket = self.socket

      if @ssl
        @ssl_socket = negotiate_ssl(socket, protocols: @protocols, sslkeylogfile: @sslkeylogfile)
      end

      socket
    end

    def socket
      @socket ||= open_socket(
        host: @host,
        port: @port,
      )
    end

    # @param [String] host
    # @param [Numeric] port
    # @return [Socket] socket
    def open_socket(host:, port:)
      # resolve the host, and choose the first address.
      # In the future this loookup could be user influenced, i.e. AF_INET/AF_INET6
      resolved_addresses = Addrinfo.getaddrinfo(host, port, 0, ::Socket::SOCK_STREAM)
      raise "Could not resolve host: #{host}" if resolved_addresses.empty?

      resolved_address = resolved_addresses.first
      logger.info("connecting to #{resolved_address.inspect}")
      # afamily will resolve to ::Socket::AF_INET/::Socket::AF_INET6
      socket = Socket.new(resolved_address.afamily, ::Socket::SOCK_STREAM, 0)
      socket_addr = Socket.sockaddr_in(port, host)

      # Connect non-blocking, but block synchronously for a connection
      begin
        socket.connect_nonblock(socket_addr)
      rescue IO::WaitWritable
        # wait for 3-way handshake completion
        socket.wait_writable
        begin
          socket.connect_nonblock(socket_addr) # check connection failure
        rescue Errno::EISCONN
          logger.info('connection opened')
        end
      end

      socket
    end

    # @return [Socket] the socket to negotiate ssl over
    # @param [String] sslkeylogfile the SSLKEYLOGFILE path
    # @param [Array<Symbol>] protocols the protocols to negotiate, i.e. [:http2, :http1_1]
    # @return [Socket]
    def negotiate_ssl(socket, protocols:, sslkeylogfile: nil)
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)

      # https://www.rfc-editor.org/rfc/rfc9113.html#name-use-of-tls-features
      if protocols.include?(:http2)
        logger.info("configuring tls for http2")
        # Implementations of HTTP/2 MUST use TLS version 1.2 [TLS12] or higher for HTTP/2 over TLS
        ssl_context.options |=
            OpenSSL::SSL::OP_NO_SSLv2 |
            OpenSSL::SSL::OP_NO_SSLv3 |
            OpenSSL::SSL::OP_NO_TLSv1 |
            OpenSSL::SSL::OP_NO_TLSv1_1

        # https://www.rfc-editor.org/rfc/rfc9113.html#appendix-A
        # ssl_context.ciphers = "..."

        # A deployment of HTTP/2 over TLS 1.2 MUST disable compression.
        # TLS compression can lead to the exposure of information that would not otherwise be revealed [RFC3749].
        ssl_context.options |= OpenSSL::SSL::OP_NO_COMPRESSION
      end

      alpn_protocols = []
      alpn_protocols << 'h2' if protocols.include?(:http2)
      alpn_protocols << 'http/1.1' if protocols.include?(:http1_1)
      ssl_context.alpn_protocols = alpn_protocols

      # write the sslkeylogfile is required, useful to decrypting tls traffic in wireshark
      if sslkeylogfile
        unless ssl_context.respond_to?(:keylog_cb)
          raise 'Unable to create sslkeylogfile - Ruby 3.2 or above required for this functionality'
        end
        ssl_context.keylog_cb = proc do |_sock, line|
          File.open(sslkeylogfile, 'ab') do |file|
            file.write("#{line}\n")
          end
        end
      end
      ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
      ssl_socket.sync_close = true

      ssl_socket.connect
      logger.info("server negotiated #{ssl_socket.alpn_protocol}")
      logger.debug(ssl_socket.session.to_text)

      ssl_socket
    end

    # @return [Symbol] The current negotiated protocol - i.e. :http2 or :http1_1
    def negotiated_protocol
      return :http1_1 if ssl_socket.nil?

      case ssl_socket.alpn_protocol
      when 'h2'
        :http2
      when 'http/1.1'
        :http1_1
      else
        ssl_socket.alpn_protocol.to_sym
      end
    end
  end
end
