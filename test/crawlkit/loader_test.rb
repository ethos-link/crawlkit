# frozen_string_literal: true

require "test_helper"

class CrawlkitLoaderTest < Minitest::Test
  def test_eager_loads_cleanly
    assert_silent do
      Crawlkit.loader.eager_load
    end
  end
end
