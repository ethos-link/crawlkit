# frozen_string_literal: true

module Crawlscope
  module Rules
    class Metadata
      TITLE_MAX_LENGTH = 72
      DESCRIPTION_MAX_LENGTH = 160

      attr_reader :code

      def initialize(site_name: nil)
        @site_name = site_name.to_s.strip
        @code = :metadata
      end

      def call(urls:, pages:, issues:, context: nil)
        pages.each do |page|
          next unless page.html?

          validate_h1(page, issues)
          validate_title(page, issues)
          validate_description(page, issues)
          validate_canonical(page, issues)
        end
      end

      private

      def validate_h1(page, issues)
        return unless page.doc.at_css("h1").nil?

        issues.add(
          code: :missing_h1,
          severity: :warning,
          category: :metadata,
          url: page.url,
          message: "missing <h1>",
          details: {}
        )
      end

      def validate_title(page, issues)
        title = page.doc.at_css("title")&.text.to_s.strip

        if title.empty?
          issues.add(code: :missing_title, severity: :warning, category: :metadata, url: page.url, message: "missing <title>", details: {})
        elsif title.length > TITLE_MAX_LENGTH
          issues.add(code: :title_too_long, severity: :warning, category: :metadata, url: page.url, message: "title too long (#{title.length})", details: {length: title.length})
        elsif repeated_site_name?(title)
          issues.add(code: :title_repeats_site_name, severity: :warning, category: :metadata, url: page.url, message: "title repeats #{@site_name}", details: {site_name: @site_name})
        end
      end

      def validate_description(page, issues)
        description = page.doc.at_css('meta[name="description"]')&.[]("content").to_s.strip

        if description.empty?
          issues.add(code: :missing_meta_description, severity: :warning, category: :metadata, url: page.url, message: "missing meta description", details: {})
        elsif description.length > DESCRIPTION_MAX_LENGTH
          issues.add(code: :meta_description_too_long, severity: :warning, category: :metadata, url: page.url, message: "meta description too long (#{description.length})", details: {length: description.length})
        end
      end

      def validate_canonical(page, issues)
        canonical = page.doc.at_css('link[rel="canonical"]')&.[]("href").to_s.strip

        if canonical.empty?
          issues.add(code: :missing_canonical, severity: :warning, category: :metadata, url: page.url, message: "missing canonical link", details: {})
          return
        end

        normalized_canonical = Url.normalize(canonical, base_url: page.url)
        normalized_page_url = Url.normalize(page.url, base_url: page.url)
        return if normalized_canonical == normalized_page_url

        issues.add(
          code: :canonical_mismatch,
          severity: :warning,
          category: :metadata,
          url: page.url,
          message: "canonical mismatch (#{canonical})",
          details: {canonical: canonical}
        )
      end

      def repeated_site_name?(title)
        return false if @site_name.empty?

        title.split(/[^[:alnum:]]+/).count { |token| token.casecmp?(@site_name) } > 1
      end
    end
  end
end
