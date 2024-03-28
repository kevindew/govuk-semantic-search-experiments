require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "debug"
  gem "dotenv"
  gem "opensearch-ruby"
end

require "dotenv/load"
require "json"
require "opensearch-ruby"

INDEX_NAME = "chunked_govuk_content"

client = OpenSearch::Client.new(url: ENV.fetch("OPENSEARCH_URL", "http://localhost:9200"))
client.indices.delete(index: INDEX_NAME) if client.indices.exists?(index: INDEX_NAME)

client.indices.create(
  index: INDEX_NAME,
  body: {
    settings: {
      index: {
        knn: true
      }
    },
    mappings: {
      properties: {
        content_id: { type: "keyword" },
        locale: { type: "keyword" },
        base_path: { type: "keyword" },
        document_type: { type: "keyword" },
        title: { type: "text" },
        content_url: { type: "keyword" },
        heading_context: { type: "text" },
        html_content: { type: "text" },
        plain_content: { type: "text" },
        openai_embedding: {
          type: "knn_vector",
          dimension: 1536,
          method: {
            name: "hnsw",
            space_type: "l2",
            engine: "faiss"
          }
        },
        digest: { type: "keyword" }
      }
    }
  }
)

files = Dir["mainstream_content/chunked_json/*.json"]

files.each.with_index(1) do |path, index|
  chunked_item = JSON.load_file(path)
  actions = chunked_item["chunks"].flat_map do |chunk|
    action = { index: { _id: chunk["id"] } }
    document_data = chunked_item.slice(*%w[content_id locale document_type base_path title])
    chunk_data = chunk.slice(*%w[content_url heading_context html_content plain_content openai_embedding digest])
    [action, document_data.merge(chunk_data)]
  end
  client.bulk(index: INDEX_NAME, body: actions)
  puts "Imported #{index} of #{files.count}" if index % 10 == 0
end

puts "All #{files.count} content items imported"
