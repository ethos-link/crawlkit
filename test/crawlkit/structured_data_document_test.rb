# frozen_string_literal: true

require "test_helper"

class CrawlkitStructuredDataDocumentTest < Minitest::Test
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

    document = Crawlkit::StructuredData::Document.new(html: html)
    items = document.items

    assert_equal 2, items.size
    assert_equal ["json-ld", "microdata"], items.map(&:source)
    assert_equal "Hotel Test", document.json_ld_items.first["name"]
  end
end
