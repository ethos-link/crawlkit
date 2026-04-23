# frozen_string_literal: true

require "concurrent"

module Crawlscope
  class Crawler
    def initialize(page_fetcher:, concurrency:)
      @page_fetcher = page_fetcher
      @concurrency = concurrency
    end

    def call(urls)
      pages = Concurrent::Array.new
      pool = Concurrent::FixedThreadPool.new(@concurrency)

      urls.each do |url|
        pool.post do
          pages << @page_fetcher.fetch(url)
        end
      end

      pool.shutdown
      pool.wait_for_termination

      pages.to_a
    end
  end
end
