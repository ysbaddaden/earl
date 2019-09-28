require "socket"
require "../earl"

module Earl
  # :nodoc:
  class TCPServer
    include Agent
    include Logger

    @server : ::TCPServer?

    def initialize(@host : String, @port : Int32, @backlog = ::Socket::SOMAXCONN, &block : Socket ->)
      @handler = block
    end

    def call
      server = ::TCPServer.new(@host, @port, backlog: @backlog)
      log.info { "started server fd=#{server.fd} host=#{@host} port=#{@port}" }
      @server = server

      while socket = server.accept?
        log.debug { "incoming connection fd=#{socket.fd}" }
        call(socket)
      end
    end

    def call(socket : ::TCPSocket)
      ::spawn do
        @handler.call(socket)
      rescue ex
        log.error(ex)
      ensure
        socket.close unless socket.closed?
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
