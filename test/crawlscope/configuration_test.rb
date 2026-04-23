# frozen_string_literal: true

require "test_helper"

class CrawlscopeConfigurationTest < Minitest::Test
  def teardown
    Crawlscope.reset!
  end

  def test_audit_builds_from_configured_callables
    Crawlscope.configure do |config|
      config.base_url = -> { "https://example.com" }
      config.sitemap_path = -> { "/tmp/sitemap.xml" }
      config.site_name = -> { "Example" }
      config.concurrency = -> { 4 }
    end

    audit = Crawlscope.configuration.audit

    assert_equal "https://example.com", audit.instance_variable_get(:@base_url)
    assert_equal "/tmp/sitemap.xml", audit.instance_variable_get(:@sitemap_path)
    assert_equal 4, audit.instance_variable_get(:@concurrency)
    assert_equal %i[metadata structured_data uniqueness links], audit.instance_variable_get(:@rules).map(&:code)
  end

  def test_audit_raises_without_base_url
    Crawlscope.configure do |config|
      config.sitemap_path = "/tmp/sitemap.xml"
    end

    error = assert_raises(Crawlscope::ConfigurationError) { Crawlscope.configuration.audit }

    assert_equal "Crawlscope base_url is not configured", error.message
  end

  def test_audit_raises_without_sitemap_path
    Crawlscope.configure do |config|
      config.base_url = "https://example.com"
    end

    error = assert_raises(Crawlscope::ConfigurationError) { Crawlscope.configuration.audit }

    assert_equal "Crawlscope sitemap_path is not configured", error.message
  end
end
