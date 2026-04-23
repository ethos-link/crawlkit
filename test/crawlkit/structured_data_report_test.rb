# frozen_string_literal: true

require "test_helper"

class CrawlkitStructuredDataReportTest < Minitest::Test
  def test_results_maps_validation_errors_and_skips
    result = Crawlkit::StructuredData::Audit::Result.new(
      entries: [
        Crawlkit::StructuredData::Audit::Entry.new(
          url: "https://example.com/article",
          status: 200,
          structured_items: [{source: "json-ld", data: {"@type" => "Article"}}],
          errors: [{type: "Article", source: "json-ld", errors: [{field: "headline", issue: "is required"}]}],
          fetch_error: nil,
          content_type: "text/html",
          skipped_reason: nil
        ),
        Crawlkit::StructuredData::Audit::Entry.new(
          url: "https://example.com/feed.xml",
          status: 200,
          structured_items: [],
          errors: [],
          fetch_error: nil,
          content_type: "application/xml",
          skipped_reason: "non-html"
        )
      ]
    )

    report = Crawlkit::StructuredData::Report.new(result)

    assert_equal [{field: "headline", issue: "is required"}], report.results["https://example.com/article"][:validation_errors]
    assert_equal "non-html", report.results["https://example.com/feed.xml"][:skipped_reason]
    assert_empty report.missing_data
    assert_equal 1, report.validation_errors.size
  end
end
