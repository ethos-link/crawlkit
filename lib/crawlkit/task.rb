# frozen_string_literal: true

require "json"

module Crawlkit
  class Task
    def initialize(configuration: Crawlkit.configuration, reporter: Reporter.new(io: configuration.output))
      @configuration = configuration
      @reporter = reporter
    end

    def validate(base_url: nil, sitemap_path: nil, rule_names: nil)
      audit = @configuration.audit(
        base_url: base_url || default_base_url,
        sitemap_path: sitemap_path || default_sitemap_path,
        rule_names: rule_names
      )

      result = audit.call
      @reporter.report(result)
      result
    end

    def validate_ldjson(urls:, debug: false, renderer: @configuration.renderer, timeout_seconds: @configuration.timeout_seconds, report_path: nil, summary: false)
      audit = StructuredData::Audit.new(
        browser_factory: @configuration.browser_factory,
        network_idle_timeout_seconds: @configuration.network_idle_timeout_seconds,
        renderer: renderer,
        schema_registry: @configuration.schema_registry,
        scroll_page: @configuration.scroll_page?,
        timeout_seconds: timeout_seconds
      )
      result = audit.call(urls: urls)

      report_ldjson_result(result, debug: debug)
      StructuredData::Writer.new(path: report_path).write(result) if report_path
      StructuredData::Reporter.new(io: @configuration.output, report_path: report_path).report(result) if summary
      result
    end

    private

    def default_base_url
      value = @configuration.base_url
      return value unless value.to_s.strip.empty?

      "http://localhost:3000"
    end

    def default_sitemap_path
      value = @configuration.sitemap_path
      return value unless value.to_s.strip.empty?

      local_path = File.expand_path("public/sitemap.xml", Dir.pwd)
      return local_path if File.exist?(local_path)

      raise ConfigurationError, "Crawlkit sitemap_path is not configured"
    end

    def report_ldjson_result(result, debug:)
      if @configuration.renderer == :browser
        @configuration.output.puts("JavaScript mode enabled (Ferrum)")
      end

      @configuration.output.puts("Validating JSON-LD on #{result.entries.size} URL(s)")
      @configuration.output.puts("")

      result.entries.each do |entry|
        @configuration.output.puts("=" * 80)
        @configuration.output.puts("URL: #{entry.url}")
        @configuration.output.puts("=" * 80)

        if entry.fetch_error
          @configuration.output.puts("Error: #{entry.fetch_error}")
          @configuration.output.puts("")
          next
        end

        if entry.status
          @configuration.output.puts("Status: #{entry.status}")
        else
          @configuration.output.puts("Status: JS runtime fetch")
        end

        @configuration.output.puts("Structured data found: #{entry.structured_items.size} (JSON-LD: #{entry.json_ld_count}, Microdata: #{entry.microdata_count})")

        if debug && entry.structured_items.any?
          @configuration.output.puts("")
          @configuration.output.puts("--- Detected Structured Data ---")

          entry.structured_items.each_with_index do |item, index|
            @configuration.output.puts("")
            @configuration.output.puts("## Item #{index + 1} [#{item[:source]}]")
            @configuration.output.puts(JSON.pretty_generate(item[:data]))
          end

          @configuration.output.puts("")
          @configuration.output.puts("--- End ---")
        end

        @configuration.output.puts("")
        @configuration.output.puts("Validation results:")

        if entry.errors.empty?
          @configuration.output.puts("  All valid!")
        else
          entry.errors.each do |error|
            @configuration.output.puts("  #{error[:type]}: INVALID [#{error[:source]}]")
            error[:errors].each do |validation_error|
              @configuration.output.puts("    - field: #{validation_error[:field]}, issue: #{validation_error[:issue]}")
            end
          end
        end

        @configuration.output.puts("")
      end

      @configuration.output.puts("STATUS: #{result.ok? ? "OK" : "FAILED"}")
    end
  end
end
