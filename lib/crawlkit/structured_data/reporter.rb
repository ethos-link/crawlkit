# frozen_string_literal: true

require "uri"

module Crawlkit
  module StructuredData
    class Reporter
      def initialize(io:, report_path: nil)
        @io = io
        @report_path = report_path
      end

      def report(result)
        report = Report.new(result)

        if report.all_valid?
          @io.puts("")
          @io.puts("All #{report.total} URLs passed validation.")
        else
          report_failures(report)
        end
      end

      private

      def extract_path(url)
        URI.parse(url).path
      rescue URI::InvalidURIError
        url
      end

      def print_category(name, items)
        return if items.empty?

        @io.puts("#{name} (#{items.size}):")
        items.each { |item| yield item }
        @io.puts("")
      end

      def report_failures(report)
        @io.puts("")
        @io.puts("VALIDATION FAILED (#{report.failure_count}/#{report.total} URLs)")
        @io.puts("")

        print_category("HTTP ERRORS", report.http_errors) do |entry|
          @io.puts("• #{extract_path(entry.url)} (#{entry.status}: #{entry.fetch_error})")
        end

        print_category("MISSING STRUCTURED DATA", report.missing_data) do |entry|
          @io.puts("• #{extract_path(entry.url)}")
        end

        print_category("VALIDATION ERRORS", report.validation_errors) do |entry|
          @io.puts("• #{extract_path(entry.url)}")

          entry.errors.each do |error|
            error[:errors].each do |validation_error|
              field = validation_error[:field] || validation_error["field"] || "$"
              issue = validation_error[:issue] || validation_error["issue"] || "Unknown error"
              @io.puts("    - #{field}: #{issue}")
            end
          end
        end

        if @report_path
          @io.puts("Full details available in: #{@report_path}")
        end

        @io.puts("#{report.failure_count} of #{report.total} URLs failed validation.")
      end
    end
  end
end
