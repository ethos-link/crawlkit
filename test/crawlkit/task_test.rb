# frozen_string_literal: true

require "test_helper"

class CrawlkitTaskTest < Minitest::Test
  FakeResult = Data.define(:reported) do
    def ok?
      true
    end
  end

  class FakeReporter
    attr_reader :result

    def report(result)
      @result = result
    end
  end

  class FakeAudit
    def initialize(result:)
      @result = result
    end

    def call
      @result
    end
  end

  class FakeConfiguration
    attr_reader :received_arguments

    def initialize(result:)
      @result = result
    end

    def audit(base_url:, sitemap_path:, rule_names:)
      @received_arguments = {
        base_url: base_url,
        sitemap_path: sitemap_path,
        rule_names: rule_names
      }

      FakeAudit.new(result: @result)
    end

    def base_url
      "https://example.com"
    end

    def sitemap_path
      "/tmp/sitemap.xml"
    end
  end

  def test_validate_passes_rule_names_to_configuration_audit
    result = FakeResult.new(reported: true)
    configuration = FakeConfiguration.new(result: result)
    reporter = FakeReporter.new

    task = Crawlkit::Task.new(configuration: configuration, reporter: reporter)
    returned_result = task.validate(rule_names: "links")

    assert_equal(
      {
        base_url: "https://example.com",
        sitemap_path: "/tmp/sitemap.xml",
        rule_names: "links"
      },
      configuration.received_arguments
    )
    assert_same result, reporter.result
    assert_same result, returned_result
  end
end
