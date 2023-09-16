require "../src/http_server"

Log.setup(:debug)

server = Earl::HTTPServer.new do |context|
  context.response.status_code = 404
  context.response << "404 NOT FOUND\n"
end

server.add_tcp_listener("::", 9292)
server.add_unix_listener("/tmp/earl.sock")

if File.exists?(File.join(__DIR__, "server.crt"))
  key = File.join(__DIR__, "server.key")
  cert = File.join(__DIR__, "server.crt")
  server.add_listener("ssl://localhost:9393?key=#{key}&cert=#{cert}")
end

Earl.application.monitor(server)
Earl.application.start
