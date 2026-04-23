# frozen_string_literal: true

module Crawlkit
  class Audit
    def initialize(base_url:, sitemap_path:, rules:, schema_registry:, browser_factory: nil, concurrency: Configuration::DEFAULT_CONCURRENCY, network_idle_timeout_seconds: Configuration::DEFAULT_BROWSER_NETWORK_IDLE_TIMEOUT_SECONDS, renderer: :http, scroll_page: Configuration::DEFAULT_BROWSER_SCROLL_PAGE, timeout_seconds: Configuration::DEFAULT_TIMEOUT_SECONDS, allowed_statuses: Configuration::DEFAULT_ALLOWED_STATUSES)
      @base_url = base_url
      @sitemap_path = sitemap_path
      @rules = Array(rules)
      @schema_registry = schema_registry
      @browser_factory = browser_factory
      @concurrency = concurrency
      @network_idle_timeout_seconds = network_idle_timeout_seconds
      @renderer = renderer.to_sym
      @scroll_page = scroll_page
      @timeout_seconds = timeout_seconds
      @allowed_statuses = allowed_statuses
    end

    def call
      urls = Sitemap.new(path: @sitemap_path).urls(base_url: @base_url)
      raise ValidationError, "No URLs found in sitemap: #{@sitemap_path}" if urls.empty?

      @page_fetcher = build_page
      pages = Crawler.new(
        page_fetcher: @page_fetcher,
        concurrency: @concurrency
      ).call(urls)

      issues = IssueCollection.new
      collect_crawl_issues(pages, issues)
      cache_pages(pages)
      context = {
        allowed_statuses: @allowed_statuses,
        base_url: @base_url,
        resolve_target: method(:resolve_target),
        schema_registry: @schema_registry
      }

      @rules.each do |rule|
        rule.call(urls: urls, pages: pages, issues: issues, context: context)
      end

      Result.new(
        base_url: @base_url,
        sitemap_path: @sitemap_path,
        urls: urls,
        pages: pages,
        issues: issues
      )
    ensure
      @page_fetcher&.close
    end

    private

    def build_browser
      Crawlkit::Browser.new(
        base_url: @base_url,
        timeout_seconds: @timeout_seconds,
        network_idle_timeout_seconds: @network_idle_timeout_seconds,
        scroll_page: @scroll_page
      )
    rescue LoadError => error
      raise ConfigurationError, "Browser rendering requires the ferrum gem (#{error.message})"
    end

    def build_page
      if @renderer == :browser
        browser_factory = @browser_factory || method(:build_browser)
        browser_factory.call
      else
        Http.new(base_url: @base_url, timeout_seconds: @timeout_seconds)
      end
    end

    def build_target_resolution(page, normalized_target_url, crawled:)
      {
        crawled: crawled,
        error: page.error,
        final_url: page.normalized_final_url || normalized_target_url,
        status: page.status
      }
    end

    def cache_pages(pages)
      @page_by_url = {}
      @target_resolution_cache = {}

      pages.each do |page|
        @page_by_url[page.normalized_url] = page unless page.normalized_url.to_s.empty?
        @page_by_url[page.normalized_final_url] = page unless page.normalized_final_url.to_s.empty?
      end
    end

    def collect_crawl_issues(pages, issues)
      pages.each do |page|
        if page.error
          issues.add(code: :fetch_failed, severity: :error, category: :crawl, url: page.url, message: page.error, details: {})
        elsif !@allowed_statuses.include?(page.status)
          issues.add(code: :unexpected_status, severity: :error, category: :crawl, url: page.url, message: "HTTP #{page.status}", details: {status: page.status})
        end
      end
    end

    def resolve_target(target_url)
      normalized_target_url = Url.normalize(target_url, base_url: @base_url)
      return @target_resolution_cache[normalized_target_url] if @target_resolution_cache.key?(normalized_target_url)

      resolution = resolve_from_crawled_page(normalized_target_url)
      resolution ||= resolve_by_fetching_target(normalized_target_url)
      @target_resolution_cache[normalized_target_url] = resolution
    end

    def resolve_by_fetching_target(normalized_target_url)
      page = @page_fetcher.fetch(normalized_target_url)
      @page_by_url[page.normalized_url] = page unless page.normalized_url.to_s.empty?
      @page_by_url[page.normalized_final_url] = page unless page.normalized_final_url.to_s.empty?
      build_target_resolution(page, normalized_target_url, crawled: false)
    end

    def resolve_from_crawled_page(normalized_target_url)
      page = @page_by_url[normalized_target_url]
      return if page.nil?

      build_target_resolution(page, normalized_target_url, crawled: true)
    end
  end
end
