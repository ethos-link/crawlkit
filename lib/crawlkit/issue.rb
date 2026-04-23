# frozen_string_literal: true

module Crawlkit
  Issue = Data.define(:code, :severity, :category, :url, :message, :details) do
    def error?
      severity == :error
    end

    def warning?
      severity == :warning
    end

    def notice?
      severity == :notice
    end
  end
end
