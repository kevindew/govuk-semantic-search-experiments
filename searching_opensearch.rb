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
QUERY = "Tell me about systolic pressure"

opensearch_client = OpenSearch::Client.new(url: ENV.fetch("OPENSEARCH_URL", "http://localhost:9200"))
openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"])


openai_response = openai_client.embeddings(
  parameters: { model: OPENAI_EMBEDDING_MODEL, input: QUERY }
)
openai_embedding = openai_response.dig("data", 0, "embedding")

# results = opensearch_client.search(
#   index: INDEX_NAME,
#   body: {
#     size: 2,
#     query: {
#       knn: {
#         openai_embedding: {
#           vector: openai_embedding,
#           k: 2
#         }
#       }
#     },
#     # avoid the noise of open ai embeddings
#     _source: { exclude: %w[openai_embedding] },
#   }
# )

results = opensearch_client.search(
  index: INDEX_NAME,
  body: {
    size: 10,
    query: {
      hybrid: {
        queries: [
          {
            match: {
              plain_content: {
                query: "blood pressure"
              }
            }
          },
          {
            knn: {
              openai_embedding: {
                vector: openai_embedding,
                k: 2
              }
            }
          }
        ]
      }
    },
    # avoid the noise of open ai embeddings
    _source: { exclude: %w[openai_embedding] },
  }
)

# results = opensearch_client.search(
#   index: INDEX_NAME,
#   body: {
#     size: 2,
#     query: {
#       match: {
#         plain_content: {
#           query: "blood pressure"
#         }
#       }
#     },
#     # avoid the noise of open ai embeddings
#     _source: { exclude: %w[openai_embedding] },
#   }
# )

debugger
