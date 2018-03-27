require "minitest/autorun"
require "../src/earl"

STDOUT.sync = true

{% if flag?(:DEBUG) %}
  Earl::Logger.level = Earl::Logger::Severity::DEBUG
{% else %}
  Earl::Logger.level = Earl::Logger::Severity::SILENT
{% end %}
