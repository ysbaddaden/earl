require "./agent"
require "./mailbox"

module Earl
  # An actor-like agent. It includes the following extension modules:
  # - `Agent`
  # - `Logger`
  # - `Mailbox(M)`
  #
  # Artists will automatically receive messages (of type `M`) and dispatch them
  # to the `#call(message)` method. `M` can be an union type and there can be as
  # many `#call(message)` method overloads to handle the different message
  # types.
  module Artist(M)
    macro included
      include Earl::Agent
      include Earl::Logger
      include Earl::Mailbox(M)
    end

    # Dispatches messages to `#call(message)` until asked to stop.
    def call
      while message = receive?
        call(message)
      end
    end

    def call(message : M)
      # this should be an abstract def, but if M is an union and the artist
      # implements specific overloads for each type in the union this would fail
      # to compile because crystal expects an explicit `call(Foo | Bar)` def to
      # exist.
      #
      # instead of merely raising, we try to detect which overload exist to
      # report a helpful message to the developer.
      #
      # See https://github.com/crystal-lang/crystal/issues/8232

      {% if M.union? %}
        {% types = [] of String %}

        {% for t in M.union_types %}
          {% for type in t.stringify.split(" | ") %}
            {% types << type %}
          {% end %}
        {% end %}

        {% for fn in @type.methods %}
          {% if fn.name == "call" && fn.args.size >= 1 %}
            {% types = types.reject do |type|
              fn.args[0].restriction.stringify.split(" | ").includes?(type)
            end %}
          {% end %}
        {% end %}

        {% for ancestor in @type.ancestors %}
          {% for fn in ancestor.methods %}
            {% if fn.name == "call" && fn.args.size >= 1 %}
              {% types = types.reject do |type|
                fn.args[0].restriction.stringify.split(" | ").includes?(type)
              end %}
            {% end %}
          {% end %}
        {% end %}

        {% raise "Error: method #{@type}#call(#{types.join(" | ").id}) must be defined" %}
      {% else %}
        {% raise "Error: method #{@type}#call(#{M}) must be defined" %}
      {% end %}
    end
  end
end
