# frozen_string_literal: true

require "test_helper"

class CrawlkitUniquenessRuleTest < Minitest::Test
  def test_reports_duplicate_title_description_and_content
    issues = Crawlkit::IssueCollection.new
    rule = Crawlkit::Rules::Uniqueness.new
    pages = [
      page(url: "https://example.com/a"),
      page(url: "https://example.com/b")
    ]

    rule.call(urls: pages.map(&:url), pages: pages, issues: issues, context: {})

    assert_equal %i[duplicate_content_fingerprint duplicate_meta_description duplicate_title].sort, issues.to_a.map(&:code).sort
  end

  private

  def page(url:)
    repeated_text = ("Useful content " * 30).strip
    body = <<~HTML
      <html>
        <head>
          <title>Example Title</title>
          <meta name="description" content="Example description">
        </head>
        <body>
          <main>#{repeated_text}</main>
        </body>
      </html>
    HTML

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
