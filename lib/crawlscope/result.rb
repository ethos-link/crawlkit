# frozen_string_literal: true

module Crawlscope
  Result = Data.define(:base_url, :sitemap_path, :urls, :pages, :issues) do
    def ok?
      issues.none?(&:error?) && issues.none?(&:warning?) && issues.none?(&:notice?)
    end
  end
end
