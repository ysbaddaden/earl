require "socket"
require "../earl"

module Earl
  # :nodoc:
  class UNIXServer
    include Agent
    include Logger

    @server : ::UNIXServer?

    def initialize(@path : String, @mode : Int32?, @backlog = ::Socket::SOMAXCONN, &block : Socket ->)
      @handler = block
    end

    def call
      server = ::UNIXServer.new(@path, backlog: @backlog)
      log.info { "started server fd=#{server.fd} path=#{@path}" }
      @server = server

      if mode = @mode
        File.chmod(@path, mode)
      end

      while socket = server.accept?
        log.debug { "incoming connection fd=#{socket.fd}" }
        call(socket)
      end
    end

    def call(socket : ::UNIXSocket)
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
    end

    def reset : Nil
      @server = nil
    end
  end
end
