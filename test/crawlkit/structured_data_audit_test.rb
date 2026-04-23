# frozen_string_literal: true

require "test_helper"

class CrawlkitStructuredDataAuditTest < Minitest::Test
  class FakeBrowser
    attr_reader :closed

    def initialize(page:)
      @page = page
      @closed = false
    end

    def close
      @closed = true
    end

    def fetch(_url)
      @page
    end
  end

  def test_reports_schema_errors_for_invalid_article_markup
    page = html_page(
      url: "https://example.com/articles/test",
      body: <<~HTML
        <html>
          <head>
            <script type="application/ld+json">
              {"@context":"https://schema.org","@type":"Article"}
            </script>
          </head>
        </html>
      HTML
    )
    browser = FakeBrowser.new(page: page)
    audit = Crawlkit::StructuredData::Audit.new(
      browser_factory: -> { browser },
      renderer: :browser,
      schema_registry: Crawlkit::SchemaRegistry.default,
      timeout_seconds: 20
    )

    result = audit.call(urls: [page.url])

    refute result.ok?
    assert_equal 1, result.entries.size
    assert_equal "Article", result.entries.first.errors.first[:type]
    assert browser.closed
  end

  def test_reports_fetch_errors_for_non_success_statuses
    page = Crawlkit::Page.new(
      url: "https://example.com/missing",
      normalized_url: "https://example.com/missing",
      final_url: "https://example.com/missing",
      normalized_final_url: "https://example.com/missing",
      status: 404,
      headers: {"content-type" => "text/html"},
      body: "",
      doc: Nokogiri::HTML("")
    )
    browser = FakeBrowser.new(page: page)
    audit = Crawlkit::StructuredData::Audit.new(
      browser_factory: -> { browser },
      renderer: :browser,
      schema_registry: Crawlkit::SchemaRegistry.default,
      timeout_seconds: 20
    )

    result = audit.call(urls: [page.url])

    refute result.ok?
    assert_equal "Non-success status", result.entries.first.fetch_error
  end

  def test_skips_non_html_responses_without_treating_them_as_missing_data
    page = Crawlkit::Page.new(
      url: "https://example.com/feed.xml",
      normalized_url: "https://example.com/feed.xml",
      final_url: "https://example.com/feed.xml",
      normalized_final_url: "https://example.com/feed.xml",
      status: 200,
      headers: {"content-type" => "application/xml"},
      body: "<feed></feed>",
      doc: nil
    )
    browser = FakeBrowser.new(page: page)
    audit = Crawlkit::StructuredData::Audit.new(
      browser_factory: -> { browser },
      renderer: :browser,
      schema_registry: Crawlkit::SchemaRegistry.default,
      timeout_seconds: 20
    )

    result = audit.call(urls: [page.url])

    assert result.ok?
    assert_equal "application/xml", result.entries.first.content_type
    assert_equal "non-html", result.entries.first.skipped_reason
    assert_predicate result.entries.first, :structured_data_found?
  end

  private

  def html_page(url:, body:)
    Crawlkit::Page.new(
      url: url,
      normalized_url: url,
      final_url: url,
      normalized_final_url: url,
      status: 200,
      headers: {"content-type" => "text/html"},
      body: body,
      doc: Nokogiri::HTML(body)
    )
  end
end
