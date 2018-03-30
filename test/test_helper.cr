require "minitest/autorun"
require "../src/earl"

{% if flag?(:DEBUG) %}
  Earl::Logger.level = Earl::Logger::Severity::DEBUG
{% else %}
  Earl::Logger.level = Earl::Logger::Severity::SILENT
{% end %}

STDOUT.sync = true
Earl.application.spawn
