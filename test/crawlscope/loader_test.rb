# frozen_string_literal: true

require "test_helper"

class CrawlscopeLoaderTest < Minitest::Test
  def test_eager_loads_cleanly
    assert_silent do
      Crawlscope.loader.eager_load
    end
  end
end
