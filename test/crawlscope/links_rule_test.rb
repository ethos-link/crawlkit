# frozen_string_literal: true

require "test_helper"

class CrawlscopeLinksRuleTest < Minitest::Test
  def test_reports_broken_internal_links
    issues = Crawlscope::IssueCollection.new
    rule = Crawlscope::Rules::Links.new
    pages = [
      page(
        url: "https://example.com/guide",
        body: <<~HTML
          <html>
            <body>
              <main>
                <a href="/pricing">Pricing</a>
                <a href="/missing">Missing</a>
              </main>
            </body>
          </html>
        HTML
      ),
      page(
        url: "https://example.com/pricing",
        body: <<~HTML
          <html>
            <body>
              <main>
                <a href="/guide">Guide</a>
              </main>
            </body>
          </html>
        HTML
      )
    ]

    rule.call(
      urls: ["https://example.com/guide", "https://example.com/pricing"],
      pages: pages,
      issues: issues,
      context: {
        allowed_statuses: [200, 301, 302],
        base_url: "https://example.com",
        resolve_target: method(:resolve_target)
      }
    )

    assert_equal [:broken_internal_link], issues.to_a.map(&:code)
    assert_includes issues.to_a.first.message, "HTTP 404"
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

  def resolve_target(target_url)
    case target_url
    when "https://example.com/guide", "https://example.com/pricing"
      {
        crawled: true,
        error: nil,
        final_url: target_url,
        status: 200
      }
    when "https://example.com/missing"
      {
        crawled: false,
        error: nil,
        final_url: target_url,
        status: 404
      }
    end
  end
end
