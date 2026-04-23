# frozen_string_literal: true

require "test_helper"

class CrawlscopeStructuredDataRuleTest < Minitest::Test
  def test_reports_schema_errors_for_invalid_article_markup
    issues = Crawlscope::IssueCollection.new
    rule = Crawlscope::Rules::StructuredData.new
    page = page(
      url: "https://example.com/articles/test",
      body: <<~HTML
        <html>
          <head>
            <script type="application/ld+json">
              {"@context":"https://schema.org","@type":"Article"}
            </script>
          </head>
          <body>
            <main><h1>Article</h1></main>
          </body>
        </html>
      HTML
    )

    rule.call(
      urls: [page.url],
      pages: [page],
      issues: issues,
      context: {schema_registry: Crawlscope::SchemaRegistry.default}
    )

    assert_equal [:structured_data_schema_error], issues.to_a.map(&:code)
    assert_includes issues.to_a.first.message, "headline"
  end

  def test_reports_parse_errors_for_invalid_json_ld
    issues = Crawlscope::IssueCollection.new
    rule = Crawlscope::Rules::StructuredData.new
    page = page(
      url: "https://example.com/articles/test",
      body: <<~HTML
        <html>
          <head>
            <script type="application/ld+json">
              {"@context":"https://schema.org","@type":"Article"
            </script>
          </head>
        </html>
      HTML
    )

    rule.call(
      urls: [page.url],
      pages: [page],
      issues: issues,
      context: {schema_registry: Crawlscope::SchemaRegistry.default}
    )

    assert_equal [:structured_data_parse_error], issues.to_a.map(&:code)
  end

  private

  def page(url:, body:)
    doc = Nokogiri::HTML(body)

    Crawlscope::Page.new(
      url: url,
      normalized_url: url,
      final_url: url,
      normalized_final_url: url,
      status: 200,
      headers: {"content-type" => "text/html"},
      body: body,
      doc: doc
    )
  end
end
