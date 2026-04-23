# frozen_string_literal: true

module Crawlkit
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/crawlkit_tasks.rake", __dir__)
    end
  end
end
