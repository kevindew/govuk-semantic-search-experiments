require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "debug"
  gem "dotenv"
  gem "pg"
  gem "ruby-openai"
end

require "debug"
require "dotenv/load"
require "openai"
require "pg"

DATABASE_URL = ENV.fetch("DATABASE_URL", "postgresql://postgres@localhost:54315/semantic_search_experiments")
OPENAI_EMBEDDING_MODEL = "text-embedding-3-small"

openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"])
database = PG.connect(DATABASE_URL)


openai_response = openai_client.embeddings(
  parameters: { model: OPENAI_EMBEDDING_MODEL, input: "Tell me about systolic pressure" }
)
openai_embedding = openai_response.dig("data", 0, "embedding")

query = <<SQL
SELECT plain_content, (openai_embeddings <-> $1) as similarity
FROM chunked_govuk_content
ORDER BY openai_embeddings <-> $1 LIMIT 5
SQL

result = database.exec_params(query, [openai_embedding]).to_a
debugger
