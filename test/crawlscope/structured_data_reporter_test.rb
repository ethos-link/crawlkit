# frozen_string_literal: true

require "stringio"
require "test_helper"

class CrawlscopeStructuredDataReporterTest < Minitest::Test
  def test_reports_failures_and_report_path
    result = Crawlscope::StructuredData::Audit::Outcome.new(
      entries: [
        Crawlscope::StructuredData::Audit::Page.new(
          url: "https://example.com/article",
          status: 200,
          structured_items: [{source: "json-ld", data: {"@type" => "Article"}}],
          errors: [{type: "Article", source: "json-ld", errors: [{field: "headline", issue: "is required"}]}],
          fetch_error: nil,
          content_type: "text/html",
          skipped_reason: nil
        )
      ]
    )
    io = StringIO.new

    Crawlscope::StructuredData::Reporter.new(io: io, report_path: "/tmp/structured_data_report.json").report(result)

    output = io.string

    assert_includes output, "VALIDATION FAILED"
    assert_includes output, "VALIDATION ERRORS (1):"
    assert_includes output, "headline: is required"
    assert_includes output, "/tmp/structured_data_report.json"
  end
end
