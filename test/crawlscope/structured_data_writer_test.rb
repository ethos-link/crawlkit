# frozen_string_literal: true

require "json"
require "test_helper"

class CrawlscopeStructuredDataWriterTest < Minitest::Test
  def test_writes_json_report
    result = Crawlscope::StructuredData::Audit::Outcome.new(
      entries: [
        Crawlscope::StructuredData::Audit::Page.new(
          url: "https://example.com/article",
          status: 200,
          structured_items: [{source: "json-ld", data: {"@type" => "Article"}}],
          errors: [],
          fetch_error: nil,
          content_type: "text/html",
          skipped_reason: nil
        )
      ]
    )
    tmp_dir = Dir.mktmpdir
    path = File.join(tmp_dir, "structured_data_report.json")

    Crawlscope::StructuredData::Writer.new(path: path).write(result)

    payload = JSON.parse(File.read(path))
    assert payload["generated_at"]
    assert_equal 1, payload["results"]["https://example.com/article"]["json_ld_count"]
  ensure
    FileUtils.rm_rf(tmp_dir) if tmp_dir
  end
end
