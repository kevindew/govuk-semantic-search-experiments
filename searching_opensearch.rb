require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "debug"
  gem "dotenv"
  gem "ruby-openai"
  gem "opensearch-ruby"
end

require "debug"
require "dotenv/load"
require "json"
require "openai"
require "opensearch-ruby"

INDEX_NAME = "chunked_govuk_content"
OPENAI_EMBEDDING_MODEL = "text-embedding-3-small"

opensearch_client = OpenSearch::Client.new(url: ENV.fetch("OPENSEARCH_URL", "http://localhost:9200"))
openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"])

openai_response = openai_client.embeddings(
  parameters: { model: OPENAI_EMBEDDING_MODEL, input: "Tell me about systolic pressure" }
)
openai_embeddings = openai_response.dig("data", 0, "embedding")

results = opensearch_client.search(
  index: INDEX_NAME,
  body: {
    size: 2,
    query: {
      knn: {
        openai_embeddings: {
          vector: openai_embeddings,
          k: 2
        }
      }
    },
    # avoid the noise of open ai embeddings
    _source: { exclude: %w[openai_embeddings] },
  }
)

debugger
