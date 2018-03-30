require "../src/sock_server"

class EchoServer < Earl::SockServer
  def call(socket)
    while line = socket.gets
      socket.puts(line)

      # TCPServer and UNIXServer automatically flush on LF, but OpenSSL doesn't
      socket.flush if socket.is_a?(OpenSSL::SSL::Socket::Server)
    end
  end
end

Earl::Logger.level = Earl::Logger::Severity::DEBUG

server = EchoServer.new
server.add_tcp_listener("::", 9292)
server.add_unix_listener("/tmp/earl.sock")

if File.exists?(File.join(__DIR__, "server.crt"))
  ssl_context = OpenSSL::SSL::Context::Server.new
  ssl_context.private_key = File.join(__DIR__, "server.key")
  ssl_context.certificate_chain = File.join(__DIR__, "server.crt")

  server.add_ssl_listener("::", 9393, ssl_context)
end

Earl.application.monitor(server)
Earl.application.start
