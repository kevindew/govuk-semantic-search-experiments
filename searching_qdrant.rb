require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "debug"
  gem "dotenv"
  gem "ruby-openai"
  gem "qdrant-ruby"
end

require "debug"
require "dotenv/load"
require "json"
require "openai"
require "qdrant"

COLLECTION_NAME = "chunked_govuk_content"
OPENAI_EMBEDDING_MODEL = "text-embedding-3-small"

qdrant_client = Qdrant::Client.new(url: ENV.fetch("QDRANT_URL", "http://localhost:6333"))
openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"])

openai_response = openai_client.embeddings(
  parameters: { model: OPENAI_EMBEDDING_MODEL, input: "Tell me about systolic pressure" }
)
openai_embeddings = openai_response.dig("data", 0, "embedding")

results = qdrant_client.points.search(
  collection_name: COLLECTION_NAME,
  vector: openai_embeddings,
  with_payload: true,
  limit: 5
)

debugger
