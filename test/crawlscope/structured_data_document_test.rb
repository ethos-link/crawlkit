# frozen_string_literal: true

require "test_helper"

class CrawlscopeStructuredDataDocumentTest < Minitest::Test
  def test_items_returns_json_ld_and_microdata_entries
    html = <<~HTML
      <html>
        <body>
          <script type="application/ld+json">
            {"@type":"Hotel","name":"Hotel Test"}
          </script>

          <div itemscope itemtype="https://schema.org/Organization">
            <span itemprop="name">Acme Hospitality</span>
          </div>
        </body>
      </html>
    HTML

    document = Crawlscope::StructuredData::Document.new(html: html)
    items = document.items

    assert_equal 2, items.size
    assert_equal ["json-ld", "microdata"], items.map(&:source)
    assert_equal "Hotel Test", document.json_ld_items.first["name"]
  end

  def test_json_ld_handles_arrays_invalid_json_and_non_object_entries
    html = <<~HTML
      <script type="application/ld+json">
        [{"@type":"WebSite","name":"Example"}, "ignored"]
      </script>
      <script type="application/ld+json">
        {"@type":
      </script>
    HTML

    document = Crawlscope::StructuredData::Document.new(html: html)

    assert_equal 2, document.items.size
    assert_equal ["WebSite"], document.json_ld_items.map { |item| item["@type"] }
    assert_equal "Invalid JSON-LD", document.items.last.data[:error]
  end

  def test_microdata_extracts_common_value_attributes
    html = <<~HTML
      <div itemscope itemtype="https://schema.org/Event">
        <meta itemprop="name" content="Launch">
        <time itemprop="startDate" datetime="2026-04-24T10:00:00Z"></time>
        <a itemprop="url" href="https://example.com/event">Event</a>
        <data itemprop="position" value="1"></data>
      </div>
    HTML

    item = Crawlscope::StructuredData::Document.new(html: html).items.first.data

    assert_equal "Event", item["@type"]
    assert_equal "Launch", item["name"]
    assert_equal "2026-04-24T10:00:00Z", item["startDate"]
    assert_equal "https://example.com/event", item["url"]
    assert_equal "1", item["position"]
  end
end
