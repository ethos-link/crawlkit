# frozen_string_literal: true

module Crawlscope
  Context = Data.define(:allowed_statuses, :base_url, :resolve_target, :schema_registry) do
    def fetch(name)
      public_send(name)
    end
  end
end
