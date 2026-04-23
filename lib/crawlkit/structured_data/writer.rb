# frozen_string_literal: true

require "json"
require "fileutils"
require "time"

module Crawlkit
  module StructuredData
    class Writer
      def initialize(path:)
        @path = path
      end

      def write(result)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(
          @path,
          JSON.pretty_generate(
            generated_at: Time.now.iso8601,
            results: Report.new(result).results
          )
        )
      end
    end
  end
end
