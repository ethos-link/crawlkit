namespace :crawlscope do
  desc "Validate sitemap URLs with the default Crawlscope rules. ENV: BASE_URL, SITEMAP, RULES, JS=1, TIMEOUT, NETWORK_IDLE_TIMEOUT, CONCURRENCY"
  task validate: :environment do
    status = Crawlscope::Cli.start(["validate"], out: $stdout, err: $stderr)
    exit(status) unless status.zero?
  end

  namespace :validate do
    desc "Validate JSON-LD on one or more URLs. ENV: URL (required, semicolon-separated), DEBUG=1, JS=1, TIMEOUT, NETWORK_IDLE_TIMEOUT, REPORT_PATH, SUMMARY=1"
    task ldjson: :environment do
      status = Crawlscope::Cli.start(["ldjson"], out: $stdout, err: $stderr)
      exit(status) unless status.zero?
    end

    desc "Validate sitemap URLs with the metadata rule. ENV: BASE_URL, SITEMAP, JS=1"
    task metadata: :environment do
      crawlscope_task_with_rules("metadata")
    end

    desc "Validate sitemap URLs with the structured_data rule. ENV: BASE_URL, SITEMAP, JS=1"
    task structured_data: :environment do
      crawlscope_task_with_rules("structured_data")
    end

    desc "Validate sitemap URLs with the uniqueness rule. ENV: BASE_URL, SITEMAP, JS=1"
    task uniqueness: :environment do
      crawlscope_task_with_rules("uniqueness")
    end

    desc "Validate sitemap URLs with the links rule. ENV: BASE_URL, SITEMAP, JS=1"
    task links: :environment do
      crawlscope_task_with_rules("links")
    end
  end

  def crawlscope_task_with_rules(rules)
    original_rules = ENV["RULES"]
    ENV["RULES"] = rules
    status = Crawlscope::Cli.start(["validate"], out: $stdout, err: $stderr)
    exit(status) unless status.zero?
  ensure
    ENV["RULES"] = original_rules
  end
end
