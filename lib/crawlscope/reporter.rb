# frozen_string_literal: true

module Crawlscope
  class Reporter
    def initialize(io:)
      @io = io
    end

    def report(result)
      @io.puts("Crawlscope validation")
      @io.puts("Base URL: #{result.base_url}")
      @io.puts("Sitemap: #{result.sitemap_path}")
      @io.puts("URLs: #{result.urls.size}")
      @io.puts("Pages: #{result.pages.size}")

      if result.ok?
        @io.puts("Status: OK")
        return
      end

      @io.puts("Status: FAILED")
      @io.puts("Issues: #{result.issues.size}")

      result.issues.by_severity.sort_by { |severity, _issues| severity.to_s }.each do |severity, issues|
        @io.puts("#{severity}: #{issues.size}")
      end

      result.issues.each do |issue|
        @io.puts("- [#{issue.severity}] #{issue.url} #{issue.message}")
      end
    end
  end
end
