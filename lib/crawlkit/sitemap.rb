# frozen_string_literal: true

require "faraday"
require "faraday/follow_redirects"
require "nokogiri"
require "uri"

module Crawlkit
  class Sitemap
    SITEMAP_NAMESPACE = {"xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9"}.freeze

    def initialize(path:)
      @path = path
    end

    def urls(base_url:)
      collect_urls(@path, base_url: base_url, visited: Set.new).uniq
    end

    private

    def collect_urls(source, base_url:, visited:)
      return [] if visited.include?(source)

      visited.add(source)
      document = Nokogiri::XML(read(source))
      root_name = document.root&.name

      if root_name == "sitemapindex"
        document.xpath("//xmlns:sitemap/xmlns:loc", SITEMAP_NAMESPACE).flat_map do |node|
          child_source = resolve_child_source(source, node.text.to_s.strip)
          collect_urls(child_source, base_url: base_url, visited: visited)
        end
      else
        document.xpath("//xmlns:url/xmlns:loc", SITEMAP_NAMESPACE).map do |node|
          Url.normalize(node.text.to_s.strip, base_url: base_url)
        end
      end
    end

    def read(source)
      if Url.remote?(source)
        connection.get(source).body
      else
        File.read(source)
      end
    end

    def resolve_child_source(parent_source, child_loc)
      return child_loc if Url.remote?(child_loc)

      if Url.remote?(parent_source)
        URI.join(parent_source, child_loc).to_s
      else
        File.expand_path(child_loc, File.dirname(parent_source))
      end
    end

    def connection
      @connection ||= Faraday.new do |faraday|
        faraday.response :follow_redirects, limit: Http::MAX_REDIRECTS
        faraday.options.timeout = 20
        faraday.options.open_timeout = 20
      end
    end
  end
end
