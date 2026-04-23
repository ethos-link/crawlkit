namespace :crawlkit do
  desc "Validate sitemap URLs with the default Crawlkit rules. ENV: BASE_URL, SITEMAP, RULES, JS=1, TIMEOUT, NETWORK_IDLE_TIMEOUT, CONCURRENCY"
  task validate: :environment do
    run_crawlkit_validation(rule_names: ENV["RULES"])
  end

  namespace :validate do
    desc "Validate JSON-LD on one or more URLs. ENV: URL (required, semicolon-separated), DEBUG=1, JS=1, TIMEOUT, NETWORK_IDLE_TIMEOUT, REPORT_PATH, SUMMARY=1"
    task ldjson: :environment do
      url_string = ENV["URL"].to_s.strip

      if url_string.empty?
        raise Crawlkit::ConfigurationError, "Crawlkit URL is not configured"
      end

      urls = url_string.split(";").map(&:strip).reject(&:empty?)
      result = resolved_crawlkit_task.validate_ldjson(
        urls: urls,
        debug: ENV["DEBUG"] == "1",
        renderer: resolved_crawlkit_renderer,
        report_path: resolved_crawlkit_report_path,
        summary: ENV["SUMMARY"] == "1"
      )

      exit(1) unless result.ok?
    end

    desc "Validate sitemap URLs with the metadata rule. ENV: BASE_URL, SITEMAP, JS=1"
    task metadata: :environment do
      run_crawlkit_validation(rule_names: "metadata")
    end

    desc "Validate sitemap URLs with the structured_data rule. ENV: BASE_URL, SITEMAP, JS=1"
    task structured_data: :environment do
      run_crawlkit_validation(rule_names: "structured_data")
    end

    desc "Validate sitemap URLs with the uniqueness rule. ENV: BASE_URL, SITEMAP, JS=1"
    task uniqueness: :environment do
      run_crawlkit_validation(rule_names: "uniqueness")
    end

    desc "Validate sitemap URLs with the links rule. ENV: BASE_URL, SITEMAP, JS=1"
    task links: :environment do
      run_crawlkit_validation(rule_names: "links")
    end
  end

  def resolve_crawlkit_base_url
    env_value = ENV["BASE_URL"].to_s.strip
    return env_value unless env_value.empty?

    configured_value = Crawlkit.configuration.base_url.to_s.strip
    return configured_value unless configured_value.empty?

    "http://localhost:3000"
  end

  def resolve_crawlkit_sitemap_path
    env_value = ENV["SITEMAP"].to_s.strip
    return env_value unless env_value.empty?

    configured_value = Crawlkit.configuration.sitemap_path.to_s.strip
    return configured_value unless configured_value.empty?

    local_path = File.expand_path("public/sitemap.xml", Dir.pwd)
    return local_path if File.exist?(local_path)

    raise Crawlkit::ConfigurationError, "Crawlkit sitemap_path is not configured"
  end

  def run_crawlkit_validation(rule_names:)
    resolved_rule_names = rule_names.to_s.strip
    resolved_rule_names = nil if resolved_rule_names.empty?

    result = resolved_crawlkit_task.validate(
      base_url: resolve_crawlkit_base_url,
      sitemap_path: resolve_crawlkit_sitemap_path,
      rule_names: resolved_rule_names
    )

    exit(1) unless result.ok?
  end

  def resolved_crawlkit_configuration
    configuration = Crawlkit.configuration
    configuration.concurrency = resolved_crawlkit_concurrency
    configuration.network_idle_timeout_seconds = resolved_crawlkit_integer_env("NETWORK_IDLE_TIMEOUT", default: configuration.network_idle_timeout_seconds, minimum: 1)
    configuration.renderer = resolved_crawlkit_renderer
    configuration.timeout_seconds = resolved_crawlkit_integer_env("TIMEOUT", default: configuration.timeout_seconds, minimum: 1)
    configuration
  end

  def resolved_crawlkit_concurrency
    configured_concurrency = resolved_crawlkit_integer_env("CONCURRENCY", default: Crawlkit.configuration.concurrency, minimum: 1)

    if resolved_crawlkit_renderer == :browser && ENV["CONCURRENCY"].to_s.strip.empty?
      browser_concurrency = Crawlkit.configuration.browser_concurrency

      if configured_concurrency > browser_concurrency
        Crawlkit.configuration.output.puts("Default JS concurrency capped at #{browser_concurrency}. Set CONCURRENCY to override.")
        browser_concurrency
      else
        configured_concurrency
      end
    else
      configured_concurrency
    end
  end

  def resolved_crawlkit_integer_env(name, default:, minimum:)
    raw_value = ENV[name].to_s.strip
    return default if raw_value.empty?

    value = Integer(raw_value, 10)

    if value < minimum
      raise ArgumentError, "#{name} must be >= #{minimum}"
    end

    value
  rescue ArgumentError => error
    raise error if error.message.start_with?("#{name} must be >=")

    raise ArgumentError, "#{name} must be an integer >= #{minimum}"
  end

  def resolved_crawlkit_renderer
    renderer = ENV["RENDERER"].to_s.strip

    if renderer.empty?
      (ENV["JS"] == "1") ? :browser : :http
    else
      renderer.to_sym
    end
  end

  def resolved_crawlkit_report_path
    report_path = ENV["REPORT_PATH"].to_s.strip
    return if report_path.empty?

    report_path
  end

  def resolved_crawlkit_task
    Crawlkit::Task.new(configuration: resolved_crawlkit_configuration)
  end
end
