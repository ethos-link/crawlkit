# frozen_string_literal: true

require "uri"

module Crawlkit
  module Rules
    class Links
      CONTEXTUAL_LINK_SELECTORS = "main a[href], article a[href]"
      INTERNAL_PATH_PREFIXES_TO_SKIP = ["/rails/", "/cdn-cgi/"].freeze
      LINK_SCHEMES_TO_SKIP = ["mailto:", "tel:", "javascript:", "data:"].freeze
      MAX_SOURCES_IN_ERROR = 3
      MIN_INBOUND_ANCHOR_LINKS = 1

      attr_reader :code

      def initialize
        @code = :links
      end

      def call(urls:, pages:, issues:, context:)
        @allowed_statuses = context.fetch(:allowed_statuses)
        @base_url = context.fetch(:base_url)
        @resolve_target = context.fetch(:resolve_target)
        @base_host = URI.parse(@base_url).host

        links = extract_links(pages)
        return if links.empty?

        resolved_links = resolve_links(links, issues)
        validate_inbound_counts(urls, pages, resolved_links, issues)
      end

      private

      def contextual_links(doc)
        links = doc.css(CONTEXTUAL_LINK_SELECTORS)
        return links unless links.empty?

        doc.css("a[href]")
      end

      def extract_links(pages)
        links = []

        pages.each do |page|
          next unless page.html?

          source_path = Url.path(page.normalized_url)
          next if source_path.nil?

          contextual_links(page.doc).each do |node|
            href = node["href"].to_s.strip
            next if href.empty?
            next if href.start_with?("#")
            next if LINK_SCHEMES_TO_SKIP.any? { |prefix| href.start_with?(prefix) }

            anchor_text = normalize_anchor_text(node.text)
            next if anchor_text.empty?

            target_url = normalize_internal_link(page.normalized_url, href)
            next if target_url.nil?

            target_path = Url.path(target_url)
            next if target_path.nil?
            next if skip_internal_path?(target_path)

            links << {
              anchor_text: anchor_text,
              source_path: source_path,
              source_url: page.normalized_url,
              target_path: target_path,
              target_url: target_url
            }
          end
        end

        links
      end

      def normalize_anchor_text(text)
        text.to_s.gsub(/\s+/, " ").strip
      end

      def normalize_internal_link(source_url, href)
        absolute_url = URI.join(source_url, href).to_s
        uri = URI.parse(absolute_url)
        return if uri.host != @base_host

        uri.fragment = nil
        Url.normalize(uri.to_s, base_url: @base_url)
      rescue URI::InvalidURIError
        nil
      end

      def report_broken_target(target_url, grouped_links, issues, status)
        source_urls = grouped_links.map { |link| link[:source_url] }.uniq.first(MAX_SOURCES_IN_ERROR)
        issues.add(
          code: :broken_internal_link,
          severity: :warning,
          category: :links,
          url: target_url,
          message: "broken internal link (HTTP #{status}, sources: #{source_urls.join(", ")})",
          details: {source_urls: source_urls, status: status}
        )
      end

      def report_unresolved_target(target_url, grouped_links, issues, resolution)
        source_urls = grouped_links.map { |link| link[:source_url] }.uniq.first(MAX_SOURCES_IN_ERROR)
        suffix = (resolution && resolution[:error]) ? " (#{resolution[:error]})" : ""

        issues.add(
          code: :unresolved_internal_link,
          severity: :warning,
          category: :links,
          url: target_url,
          message: "unable to validate internal link#{suffix} (sources: #{source_urls.join(", ")})",
          details: {error: resolution && resolution[:error], source_urls: source_urls}
        )
      end

      def resolve_links(links, issues)
        resolved_links = []

        links.group_by { |link| link[:target_url] }.each do |target_url, grouped_links|
          resolution = @resolve_target.call(target_url)
          if resolution.nil?
            report_unresolved_target(target_url, grouped_links, issues, resolution)
            next
          end

          status = resolution[:status]

          if status.nil?
            next if resolution[:crawled] && resolution[:error]

            report_unresolved_target(target_url, grouped_links, issues, resolution)
            next
          end

          unless @allowed_statuses.include?(status)
            report_broken_target(target_url, grouped_links, issues, status)
            next
          end

          final_url = resolution[:final_url].to_s.empty? ? target_url : resolution[:final_url]
          final_path = Url.path(final_url)
          next if final_path.nil?
          next if skip_internal_path?(final_path)

          grouped_links.each do |link|
            resolved_links << link.merge(final_path: final_path, final_url: final_url)
          end
        end

        resolved_links
      end

      def skip_internal_path?(path)
        return true if path == "/"

        INTERNAL_PATH_PREFIXES_TO_SKIP.any? { |prefix| path.start_with?(prefix) }
      end

      def validate_inbound_counts(urls, pages, resolved_links, issues)
        sitemap_paths = urls.each_with_object({}) do |url, memo|
          normalized_url = Url.normalize(url, base_url: @base_url)
          path = Url.path(normalized_url)
          next if path.nil?
          next if skip_internal_path?(path)

          memo[path] = normalized_url
        end

        html_paths = pages.each_with_object(Set.new) do |page, result|
          next unless page.html?

          [page.normalized_url, page.normalized_final_url].compact.each do |url|
            path = Url.path(url)
            next if path.nil?
            next if skip_internal_path?(path)

            result << path
          end
        end

        inbound_anchor_counts = Hash.new(0)
        sample_sources_by_target = Hash.new { |hash, key| hash[key] = [] }

        resolved_links.each do |link|
          target_path = link[:final_path]
          next unless sitemap_paths.key?(target_path)
          next if link[:source_path] == target_path

          inbound_anchor_counts[target_path] += 1
          source_samples = sample_sources_by_target[target_path]
          source_samples << link[:source_url] unless source_samples.include?(link[:source_url])
        end

        sitemap_paths.each do |path, target_url|
          next unless html_paths.include?(path)

          inbound_count = inbound_anchor_counts[path]
          next if inbound_count >= MIN_INBOUND_ANCHOR_LINKS

          source_samples = sample_sources_by_target[path].first(MAX_SOURCES_IN_ERROR)
          source_info = source_samples.any? ? " (sources: #{source_samples.join(", ")})" : ""

          issues.add(
            code: :low_inbound_anchor_links,
            severity: :warning,
            category: :links,
            url: target_url,
            message: "inbound anchor links #{inbound_count} below #{MIN_INBOUND_ANCHOR_LINKS}#{source_info}",
            details: {inbound_count: inbound_count, minimum: MIN_INBOUND_ANCHOR_LINKS, source_urls: source_samples}
          )
        end
      end
    end
  end
end
