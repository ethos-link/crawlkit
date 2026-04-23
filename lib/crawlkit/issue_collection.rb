# frozen_string_literal: true

module Crawlkit
  class IssueCollection
    include Enumerable

    def initialize(issues = [])
      @issues = issues.dup
    end

    def add(issue = nil, **attributes)
      issue ||= Issue.new(**attributes)
      @issues << issue
      issue
    end

    def any?
      @issues.any?
    end

    def each(&block)
      @issues.each(&block)
    end

    def size
      @issues.size
    end

    def to_a
      @issues.dup
    end

    def by_category
      @issues.group_by(&:category)
    end

    def by_severity
      @issues.group_by(&:severity)
    end
  end
end
