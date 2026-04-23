# frozen_string_literal: true

require "uri"
require "zeitwerk"

module Crawlkit
  class Error < StandardError; end

  class ConfigurationError < Error; end
  class ValidationError < Error; end

  class << self
    attr_reader :loader

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset!
      @configuration = Configuration.new
    end
  end
end

Crawlkit.instance_variable_set(:@loader, Zeitwerk::Loader.for_gem)
Crawlkit.loader.ignore("#{__dir__}/tasks")
Crawlkit.loader.ignore("#{__dir__}/crawlkit/railtie.rb")
Crawlkit.loader.setup

require "crawlkit/railtie" if defined?(Rails::Railtie)
