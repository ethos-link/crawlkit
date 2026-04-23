# frozen_string_literal: true

module Crawlkit
  class Page
    attr_reader :body, :doc, :error, :final_url, :headers, :normalized_final_url, :normalized_url, :status, :url

    def initialize(url:, normalized_url:, final_url:, normalized_final_url:, status:, headers:, body:, doc:, error: nil)
      @url = url
      @normalized_url = normalized_url
      @final_url = final_url
      @normalized_final_url = normalized_final_url
      @status = status
      @headers = headers || {}
      @body = body
      @doc = doc
      @error = error
    end

    def html?
      !doc.nil?
    end
  end
end
