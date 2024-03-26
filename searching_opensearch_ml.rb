require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "debug"
  gem "dotenv"
  gem "opensearch-ruby"
end

require "debug"
require "dotenv/load"
require "json"
require "opensearch-ruby"

INDEX_NAME = "chunked_govuk_content"

client = OpenSearch::Client.new(url: ENV.fetch("OPENSEARCH_URL", "http://localhost:9202"))

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

debugger
