# frozen_string_literal: true

require "digest"

module Crawlscope
  module Rules
    class Uniqueness
      attr_reader :code

      def initialize
        @code = :uniqueness
      end

      def call(urls:, pages:, issues:, context:)
        page_summaries = pages.filter_map do |page|
          next unless page.html?

          summary_for(page)
        end

        validate_duplicates(page_summaries, issues)
      end

      private

      def content_fingerprint_digest(doc)
        text = doc.at_css("main")&.text.to_s
        text = doc.at_css("body")&.text.to_s if text.empty?
        normalized = text.gsub(/\s+/, " ").strip
        return if normalized.length < 200

        Digest::SHA256.hexdigest(normalized)
      end

      def duplicates_for(pages, field)
        pages
          .select { |page| !page[field].nil? && !page[field].to_s.empty? }
          .group_by { |page| page[field] }
          .transform_values { |items| items.map { |item| item[:url] } }
          .select { |_value, urls| urls.size > 1 }
      end

      def summary_for(page)
        {
          content_fingerprint_digest: content_fingerprint_digest(page.doc),
          description: page.doc.at_css('meta[name="description"]')&.[]("content").to_s.strip,
          title: page.doc.at_css("title")&.text.to_s.strip,
          url: page.url
        }
      end

      def validate_duplicates(page_summaries, issues)
        duplicates_for(page_summaries, :title).each do |value, urls|
          issues.add(
            code: :duplicate_title,
            severity: :warning,
            category: :uniqueness,
            url: nil,
            message: "duplicate title '#{value}' => #{urls.join(", ")}",
            details: {urls: urls, value: value}
          )
        end

        duplicates_for(page_summaries, :description).each do |value, urls|
          issues.add(
            code: :duplicate_meta_description,
            severity: :warning,
            category: :uniqueness,
            url: nil,
            message: "duplicate meta description '#{value}' => #{urls.join(", ")}",
            details: {urls: urls, value: value}
          )
        end

        duplicates_for(page_summaries, :content_fingerprint_digest).each_value do |urls|
          issues.add(
            code: :duplicate_content_fingerprint,
            severity: :warning,
            category: :uniqueness,
            url: nil,
            message: "duplicate page content fingerprint => #{urls.join(", ")}",
            details: {urls: urls}
          )
        end
      end
    end
  end
end
