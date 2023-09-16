require "openssl"
require "socket"
require "../earl"

module Earl
  # :nodoc:
  class SSLServer
    include Agent

    @server : ::TCPServer?

    def initialize(@host : String, @port : Int32, @ssl_context : OpenSSL::SSL::Context::Server, @backlog = ::Socket::SOMAXCONN, &block : Socket ->)
      @handler = block
    end

    def call
      server = ::TCPServer.new(@host, @port, backlog: @backlog)
      log.info { "started server fd=#{server.fd} host=#{@host} port=#{@port}" }
      @server = server

      while tcp_socket = server.accept?
        log.debug { "incoming connection fd=#{tcp_socket.fd}" }
        call(tcp_socket)
      end
    end

    def call(tcp_socket : ::TCPSocket)
      ::spawn do
        ssl_socket = OpenSSL::SSL::Socket::Server.new(tcp_socket, @ssl_context, sync_close: true) rescue nil
        @handler.call(ssl_socket) if ssl_socket
      rescue ex
        log.error(exception: ex) { "error" }
      ensure
        ssl_socket.close if ssl_socket && !ssl_socket.closed?
        tcp_socket.close unless tcp_socket.closed?
      end
    end

    def terminate : Nil
      if server = @server
        server.close unless server.closed?
      end
      @server = nil
    end

    def reset : Nil
      @server = nil
    end

    def started? : Bool
      !@server.nil?
    end
  end
end
