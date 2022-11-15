# frozen_string_literal: true

autoload :Socket, 'socket'
autoload :Addrinfo, 'socket'
autoload :Logger, 'logger'
autoload :OpenSSL, 'openssl'

module RubyHttp2
  class Client
    # @param [String] host
    # @param [Numeric] port
    # @param [Symbol] protocol One of http1_1 or http2
    # @param [Boolean] ssl
    # @param [Socket] socket
    # @param [String,nil] sslkeylogfile The SSLKEYLOGFILE path
    # @param [Logger] logger
    # @return [RubyHttp2::Client]
    def initialize(
      host: nil,
      port: nil,
      protocol: nil,
      ssl: false,
      socket: nil,
      sslkeylogfile: nil,
      logger: Logger.new(nil)
    )
      @host = host
      @port = port
      @protocol = protocol
      @ssl = ssl
      @socket = socket
      @sslkeylogfile = sslkeylogfile
      @logger = logger
    end

    # @param [String] path The path, i.e /foo.html
    def get(path, protocol: nil, headers: [])
      protocol ||= @protocol

      if protocol == :http1_1
        Protocol::Http1_1.new.get(socket, path, headers: headers)
      else
        raise "unsupported protocol #{protocol}"
      end
    end

    protected

    # The logger
    # @!attribute [r] logger
    #   @return [Logger]
    attr_reader :logger

    def socket
      @socket ||= open_socket(host: @host, port: @port, ssl: @ssl, sslkeylogfile: @sslkeylogfile)
    end

    # @param [String] host
    # @param [Numeric] port
    # @param [Boolean] ssl
    # @param [String] sslkeylogfile the SSLKEYLOGFILE path
    # @return [Socket] socket
    def open_socket(host:, port:, ssl:, sslkeylogfile: nil)
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

      if ssl
        ssl_context = OpenSSL::SSL::SSLContext.new
        ssl_context.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
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
        socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
        socket.sync_close = true

        socket.connect
        logger.debug(socket.session.to_text)
      end

      socket
    end
  end
end
