require "./test_helper"
require "../src/sock_server"

private class EchoServer < Earl::SockServer
  def call(socket : Earl::Socket) : Nil
    while line = socket.gets
      socket << line << '\n'
      socket.flush
    end
  end
end

module Earl
  class SockServerTest < Minitest::Test
    def test_add_many_listeners
      server = EchoServer.new

      ssl_context = OpenSSL::SSL::Context::Server.new
      ssl_context.private_key = File.expand_path("../samples/server.key", __DIR__)
      ssl_context.certificate_chain = File.expand_path("../samples/server.crt", __DIR__)

      server.add_tcp_listener("127.0.0.1", 9494)
      server.add_ssl_listener("127.0.0.1", 9595, ssl_context)
      server.add_unix_listener("/tmp/earl_test_#{Process.pid}.sock")

      server.spawn
      eventually { assert server.started? }

      done = Channel(Nil).new

      spawn do
        TCPSocket.open("127.0.0.1", 9494) do |socket|
          # use buffer to send/read messages otherwise it takes seconds to run:
          999.times { |i| socket.puts "hello julien #{i} (TCP)" }
          999.times { |i| assert_equal "hello julien #{i} (TCP)", socket.gets }
        end
        done.send(nil)
      end

      spawn do
        TCPSocket.open("127.0.0.1", 9595) do |tcp_socket|
          ctx = OpenSSL::SSL::Context::Client.new
          ctx.verify_mode = OpenSSL::SSL::VerifyMode::NONE

          OpenSSL::SSL::Socket::Client.open(tcp_socket, ctx, sync_close: true) do |socket|
            999.times do |i|
              socket.puts "hello julien #{i} (SSL)"
              # openssl doesn't flush automagically on LF:
              socket.flush
              assert_equal "hello julien #{i} (SSL)", socket.gets
            end
          end
        end
        done.send(nil)
      end

      spawn do
        UNIXSocket.open("/tmp/earl_test_#{Process.pid}.sock") do |socket|
          999.times do |i|
            socket.puts "hello julien #{i} (UNIX)"
            assert_equal "hello julien #{i} (UNIX)", socket.gets
          end
        end
        done.send(nil)
      end

      3.times { done.receive }

      server.stop
    end
  end
end
