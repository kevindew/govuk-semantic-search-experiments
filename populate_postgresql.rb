require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "debug"
  gem "pg"
  gem "pgvector"
end

require "json"
require "uri"
require "pgvector"


TABLE_NAME = "chunked_govuk_content"
DATABASE_URL = ENV.fetch("DATABASE_URL", "postgresql://postgres@localhost:54315/semantic_search_experiments")

database_uri = URI.parse(DATABASE_URL)

connect_credentials = {
  user: database_uri.user,
  password: database_uri.password,
  host: database_uri.host,
  port: database_uri.port,
}

PG.connect(connect_credentials) do |conn|
  conn.exec(%Q{CREATE DATABASE "#{database_uri.path.delete_prefix('/')}"})
rescue PG::DuplicateDatabase
  puts "skipping creating DB as already exists"
end

conn = PG.connect(DATABASE_URL)

conn.exec("CREATE EXTENSION IF NOT EXISTS vector")
conn.exec("DROP TABLE IF EXISTS #{TABLE_NAME}")

# If we were going with postgres for real we might want to use separate tables for content and chunks
# I gave up using Sequel for create table as that got tricky with the vectors
create_table_query = <<-SQL
  CREATE TABLE #{TABLE_NAME}(
    id text PRIMARY KEY,
    content_id text,
    locale text,
    base_path text,
    title text,
    content_url text,
    heading_context text[],
    html_content text,
    plain_content text,
    openai_embedding vector (1536),
    digest text
  )
SQL
conn.exec(create_table_query)
conn.exec("CREATE INDEX index_#{TABLE_NAME}_openai_embedding_hnsw ON #{TABLE_NAME} USING hnsw(openai_embedding vector_cosine_ops);")

Dir["mainstream_content/chunked_json/*.json"].each do |path|
  chunked_item = JSON.load_file(path)
  chunked_item["chunks"].each do |chunk|
    insert_query = <<~SQL
      INSERT INTO #{TABLE_NAME}
      (id, content_id, locale, base_path, title, content_url, heading_context, html_content, plain_content, openai_embedding, digest)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
    SQL
    conn.exec_params(insert_query, [
      chunk["id"],
      chunked_item["content_id"],
      chunked_item["locale"],
      chunked_item["base_path"],
      chunked_item["title"],
      chunk["content_url"],
      "{" + chunk["heading_context"].join(",") + "}", # an array input doesn't get parsed correctly
      chunk["html_content"],
      chunk["plain_content"],
      chunk["openai_embedding"],
      chunk["digest"]
    ])
    end
  end
