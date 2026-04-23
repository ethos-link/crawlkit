# frozen_string_literal: true

module Crawlscope
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/crawlscope_tasks.rake", __dir__)
    end
  end
end
