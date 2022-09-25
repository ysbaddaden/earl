require "./sock_server"
require "http/server"

module Earl
  # A HTTP/1 server.
  #
  # The server is based on `SockServer`, thus binds and listens on many
  # interfaces and ports (TCP, SSL, UNIX). Leverages `HTTP::Server` request
  # processor and thus supports all `HTTP::Handler` middlewares.
  class HTTPServer < SockServer
    @handler : HTTP::Handler | Proc(HTTP::Server::Context, Nil)

    def initialize(handlers = [] of HTTP::Handler, &block : HTTP::Server::Context ->)
      @handler = if handlers.empty?
                   block
                 else
                   HTTP::Server.build_middleware(handlers, block)
                 end
      @request_processor = HTTP::Server::RequestProcessor.new(@handler)
      super()
    end

    def initialize(handlers : Array(HTTP::Handler))
      @handler = HTTP::Server.build_middleware(handlers)
      @request_processor = HTTP::Server::RequestProcessor.new(@handler)
      super()
    end

    # Processes the incoming HTTP connection.
    def call(socket : Earl::Socket)
      @request_processor.process(socket, socket)
    end

    def terminate
      super
      @request_processor.close
    end

    def reset
      super
      @request_processor = HTTP::Server::RequestProcessor.new(@handler)
    end
  end
end
