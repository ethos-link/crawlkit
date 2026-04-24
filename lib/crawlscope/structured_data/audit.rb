# frozen_string_literal: true

module Crawlscope
  module StructuredData
    class Audit
      Page = Data.define(:url, :status, :structured_items, :errors, :fetch_error, :content_type, :skipped_reason) do
        def json_ld_count
          structured_items.count { |item| item[:source] == "json-ld" }
        end

        def microdata_count
          structured_items.count { |item| item[:source] == "microdata" }
        end

        def ok?
          fetch_error.nil? && errors.empty?
        end

        def structured_data_found?
          skipped_reason == "non-html" || structured_items.any?
        end
      end

      Outcome = Data.define(:entries) do
        def ok?
          entries.all?(&:ok?)
        end
      end

      def initialize(schema_registry:, renderer:, timeout_seconds:, browser_factory: nil, network_idle_timeout_seconds: Configuration::DEFAULT_BROWSER_NETWORK_IDLE_TIMEOUT_SECONDS, scroll_page: Configuration::DEFAULT_BROWSER_SCROLL_PAGE)
        @schema_registry = schema_registry
        @renderer = renderer.to_sym
        @timeout_seconds = timeout_seconds
        @browser_factory = browser_factory
        @network_idle_timeout_seconds = network_idle_timeout_seconds
        @scroll_page = scroll_page
      end

      def call(urls:)
        fetcher = build_fetcher(urls)
        entries = urls.map { |url| validate_url(url, fetcher) }

        Outcome.new(entries: entries)
      ensure
        fetcher&.close
      end

      private

      def build_browser(base_url)
        browser_factory = @browser_factory

        if browser_factory
          browser_factory.call
        else
          Crawlscope::Browser.new(
            base_url: base_url,
            timeout_seconds: @timeout_seconds,
            network_idle_timeout_seconds: @network_idle_timeout_seconds,
            scroll_page: @scroll_page
          )
        end
      rescue LoadError => error
        raise ConfigurationError, "Browser rendering requires the ferrum gem (#{error.message})"
      end

      def build_fetcher(urls)
        first_url = urls.first.to_s
        base_url = first_url.empty? ? "http://localhost:3000" : first_url

        if @renderer == :browser
          build_browser(base_url)
        else
          Crawlscope::Http.new(base_url: base_url, timeout_seconds: @timeout_seconds)
        end
      end

      def build_validation_errors(page)
        document = Document.new(html: page.body)
        structured_items = document.items.map do |item|
          {
            data: item.data,
            source: item.source
          }
        end

        errors = structured_items.filter_map do |item|
          if item[:data].is_a?(Hash) && item[:data][:error]
            {
              errors: [{field: "parse", issue: item[:data][:message]}],
              source: item[:source],
              type: item[:source]
            }
          else
            schema_errors = @schema_registry.validate(item[:data])
            next if schema_errors.empty?

            {
              errors: schema_errors,
              source: item[:source],
              type: item[:data]["@type"] || item[:source]
            }
          end
        end

        [structured_items, errors]
      end

      def validate_url(url, fetcher)
        page = fetcher.fetch(url)
        content_type = page.headers["content-type"].to_s

        if page.error
          Page.new(url: url, status: page.status, structured_items: [], errors: [], fetch_error: page.error, content_type: content_type, skipped_reason: nil)
        elsif page.status && !(200..299).cover?(page.status.to_i)
          Page.new(
            url: url,
            status: page.status,
            structured_items: [],
            errors: [],
            fetch_error: "Non-success status",
            content_type: content_type,
            skipped_reason: nil
          )
        elsif !content_type.empty? && !content_type.include?("text/html")
          Page.new(
            url: url,
            status: page.status,
            structured_items: [],
            errors: [],
            fetch_error: nil,
            content_type: content_type,
            skipped_reason: "non-html"
          )
        else
          structured_items, errors = build_validation_errors(page)
          Page.new(
            url: url,
            status: page.status,
            structured_items: structured_items,
            errors: errors,
            fetch_error: nil,
            content_type: content_type,
            skipped_reason: nil
          )
        end
      end
    end
  end
end
