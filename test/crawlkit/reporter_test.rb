# frozen_string_literal: true

require "stringio"
require "test_helper"

class CrawlkitReporterTest < Minitest::Test
  def test_reports_ok_result
    io = StringIO.new
    result = Crawlkit::Result.new(
      base_url: "https://example.com",
      sitemap_path: "/tmp/sitemap.xml",
      urls: ["https://example.com"],
      pages: [Object.new],
      issues: Crawlkit::IssueCollection.new
    )

    Crawlkit::Reporter.new(io: io).report(result)

    output = io.string

    assert_includes output, "Crawlkit validation"
    assert_includes output, "Status: OK"
    refute_includes output, "Status: FAILED"
  end

  def test_reports_failed_result_with_severity_counts
    io = StringIO.new
    issues = Crawlkit::IssueCollection.new
    issues.add(code: :missing_title, severity: :warning, category: :metadata, url: "https://example.com/a", message: "missing <title>", details: {})
    issues.add(code: :broken_internal_link, severity: :notice, category: :links, url: "https://example.com/b", message: "broken internal link", details: {})
    result = Crawlkit::Result.new(
      base_url: "https://example.com",
      sitemap_path: "/tmp/sitemap.xml",
      urls: ["https://example.com/a", "https://example.com/b"],
      pages: [Object.new, Object.new],
      issues: issues
    )

    Crawlkit::Reporter.new(io: io).report(result)

    output = io.string

    assert_includes output, "Status: FAILED"
    assert_includes output, "Issues: 2"
    assert_includes output, "notice: 1"
    assert_includes output, "warning: 1"
    assert_includes output, "- [warning] https://example.com/a missing <title>"
    assert_includes output, "- [notice] https://example.com/b broken internal link"
  end
end
