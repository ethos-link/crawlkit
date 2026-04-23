# frozen_string_literal: true

require "json-schema"

module Crawlkit
  class SchemaRegistry
    FAQ_PAGE = {
      "type" => "object",
      "required" => ["@context", "@type", "mainEntity"],
      "properties" => {
        "@context" => {"const" => "https://schema.org"},
        "@type" => {"const" => "FAQPage"},
        "mainEntity" => {
          "type" => "array",
          "minItems" => 1,
          "items" => {"$ref" => "#/definitions/Question"}
        }
      },
      "definitions" => {
        "Question" => {
          "type" => "object",
          "required" => ["@type", "name", "acceptedAnswer"],
          "properties" => {
            "@type" => {"const" => "Question"},
            "name" => {"type" => "string"},
            "acceptedAnswer" => {"$ref" => "#/definitions/Answer"}
          }
        },
        "Answer" => {
          "type" => "object",
          "required" => ["@type", "text"],
          "properties" => {
            "@type" => {"const" => "Answer"},
            "text" => {"type" => "string"}
          }
        }
      }
    }.freeze

    ARTICLE = {
      type: "object",
      required: ["@type", "headline"],
      properties: {
        "@type" => {enum: ["Article", "NewsArticle", "BlogPosting"]},
        :headline => {type: "string", maxLength: 110},
        :image => {type: "string", format: "uri"},
        :datePublished => {type: "string", format: "date-time"},
        :dateModified => {type: "string", format: "date-time"},
        :author => {type: "object"},
        :publisher => {type: "object"}
      }
    }.freeze

    ORGANIZATION = {
      type: "object",
      required: ["@type", "name"],
      properties: {
        "@type" => {const: "Organization"},
        :name => {type: "string"},
        :url => {type: "string", format: "uri"},
        :logo => {
          anyOf: [
            {type: "string", format: "uri"},
            {
              type: "object",
              required: ["@type", "url"],
              properties: {
                "@type" => {const: "ImageObject"},
                :url => {type: "string", format: "uri"}
              }
            }
          ]
        },
        :description => {type: "string"}
      }
    }.freeze

    OFFER = {
      type: "object",
      additionalProperties: true,
      required: ["@type"],
      properties: {
        "@type" => {const: "Offer"},
        :name => {type: ["string", "null"]},
        :price => {type: ["string", "number"]},
        :priceCurrency => {type: ["string", "null"]},
        :availability => {type: "string"},
        :url => {type: "string", format: "uri"}
      }
    }.freeze

    RATING = {
      type: "object",
      required: ["@type", "ratingValue"],
      properties: {
        "@type" => {const: "Rating"},
        :ratingValue => {type: ["string", "number"]},
        :bestRating => {type: ["string", "number"]},
        :worstRating => {type: ["string", "number"]}
      }
    }.freeze

    REVIEW = {
      type: "object",
      required: ["@type", "itemReviewed"],
      properties: {
        "@type" => {const: "Review"},
        :itemReviewed => {type: "object"},
        :reviewRating => RATING,
        :author => {type: ["object", "string"]},
        :datePublished => {type: "string", format: "date-time"},
        :reviewBody => {type: "string"}
      }
    }.freeze

    REVIEW_SNIPPET = {
      type: "object",
      required: ["@type", "reviewRating"],
      properties: {
        "@type" => {const: "Review"},
        :reviewRating => RATING,
        :author => {type: ["object", "string"]},
        :reviewBody => {type: "string"},
        :datePublished => {type: "string", format: "date-time"}
      }
    }.freeze

    AGGREGATE_RATING = {
      type: "object",
      required: ["@type"],
      properties: {
        "@type" => {const: "AggregateRating"},
        :ratingValue => {type: ["string", "number"]},
        :ratingCount => {type: "integer"},
        :reviewCount => {type: "integer"},
        :bestRating => {type: ["string", "number"]},
        :worstRating => {type: ["string", "number"]}
      }
    }.freeze

    SOFTWARE_APPLICATION = {
      type: "object",
      required: ["@type", "name"],
      properties: {
        "@type" => {const: "SoftwareApplication"},
        :name => {type: "string"},
        :applicationCategory => {type: "string"},
        :description => {type: "string"},
        :offers => {
          anyOf: [
            OFFER,
            {type: "array", items: OFFER}
          ]
        },
        :featureList => {type: ["string", "array"]},
        :aggregateRating => AGGREGATE_RATING,
        :review => REVIEW_SNIPPET
      }
    }.freeze

    WEB_APPLICATION = {
      type: "object",
      required: ["@type", "name"],
      properties: {
        "@type" => {const: "WebApplication"},
        :name => {type: "string"},
        :applicationCategory => {type: "string"},
        :description => {type: "string"},
        :operatingSystem => {type: "string"},
        :url => {type: "string", format: "uri"},
        :offers => {
          anyOf: [
            OFFER,
            {type: "array", items: OFFER}
          ]
        },
        :featureList => {type: ["string", "array"]},
        :aggregateRating => AGGREGATE_RATING,
        :review => REVIEW_SNIPPET
      }
    }.freeze

    CONTACT_PAGE = {
      type: "object",
      required: ["@type", "name"],
      properties: {
        "@type" => {const: "ContactPage"},
        :name => {type: "string"},
        :description => {type: "string"},
        :url => {type: "string", format: "uri"}
      }
    }.freeze

    PRODUCT = {
      type: "object",
      required: ["@type", "name"],
      properties: {
        "@type" => {const: "Product"},
        :name => {type: "string"},
        :description => {type: "string"},
        :offers => {
          anyOf: [
            OFFER,
            {type: "array", items: OFFER}
          ]
        }
      }
    }.freeze

    WEBSITE = {
      type: "object",
      required: ["@type"],
      properties: {
        "@type" => {const: "WebSite"},
        :name => {type: "string"},
        :url => {type: "string", format: "uri"},
        :potentialAction => {type: "object"}
      }
    }.freeze

    BREADCRUMB_LIST = {
      type: "object",
      required: ["@type", "itemListElement"],
      properties: {
        "@type" => {const: "BreadcrumbList"},
        :itemListElement => {
          type: "array",
          minItems: 1,
          items: {
            type: "object",
            required: ["@type", "position", "name", "item"],
            properties: {
              "@type" => {const: "ListItem"},
              :position => {type: "integer", minimum: 1},
              :name => {type: "string"},
              :item => {type: "string", format: "uri"}
            }
          }
        }
      }
    }.freeze

    WEB_PAGE = {
      type: "object",
      required: ["@type"],
      properties: {
        "@type" => {const: "WebPage"}
      }
    }.freeze

    def initialize(schemas: {})
      @schemas = schemas.transform_keys(&:to_s).dup
    end

    def self.default
      new(
        schemas: {
          "FAQPage" => FAQ_PAGE,
          "Article" => ARTICLE,
          "NewsArticle" => ARTICLE,
          "BlogPosting" => ARTICLE,
          "Organization" => ORGANIZATION,
          "SoftwareApplication" => SOFTWARE_APPLICATION,
          "WebApplication" => WEB_APPLICATION,
          "ContactPage" => CONTACT_PAGE,
          "Product" => PRODUCT,
          "Review" => REVIEW,
          "WebSite" => WEBSITE,
          "BreadcrumbList" => BREADCRUMB_LIST,
          "WebPage" => WEB_PAGE
        }
      )
    end

    def dup
      self.class.new(schemas: deep_copy(@schemas))
    end

    def fetch(type)
      @schemas.fetch(type.to_s)
    end

    def register(type, schema)
      @schemas[type.to_s] = schema
      self
    end

    def registered?(type)
      @schemas.key?(type.to_s)
    end

    def validate(item)
      if item.is_a?(Array)
        return item.flat_map { |entry| validate(entry) }
      end

      errors = []

      if item.is_a?(Hash) && item["@graph"].is_a?(Array)
        item["@graph"].each do |graph_item|
          errors.concat(validate(graph_item))
        end
      end

      type = item.is_a?(Hash) ? item["@type"] : nil
      return errors if type.nil?

      schema = @schemas[type.to_s]
      return errors if schema.nil?

      JSON::Validator.fully_validate(schema, item, errors_as_objects: true).each do |error|
        errors << {
          field: error[:fragment].to_s.sub("#/", ""),
          issue: error[:message],
          type: type
        }
      end

      errors
    rescue JSON::Schema::ValidationError => error
      [{field: "unknown", issue: error.message, type: type}]
    end

    def to_h
      @schemas.dup
    end

    private

    def deep_copy(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, entry), copy|
          copy[key] = deep_copy(entry)
        end
      when Array
        value.map { |entry| deep_copy(entry) }
      else
        value
      end
    end
  end
end
