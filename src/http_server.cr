require "./sock_server"
require "http/server"

module Earl
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

    def call(socket)
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
