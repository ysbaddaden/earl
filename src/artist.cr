require "./agent"
require "./mailbox"

module Earl
  module Artist(M)
    macro included
      include Earl::Agent
      include Earl::Logger
      include Earl::Mailbox(M)

      def call
        while message = receive?
          call(message)
        end
      end
    end
  end
end
