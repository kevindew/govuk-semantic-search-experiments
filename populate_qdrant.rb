require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "debug"
  gem "qdrant-ruby"
end

require "json"
require "qdrant"

COLLECTION_NAME = "chunked_govuk_content"

client = Qdrant::Client.new(url: ENV.fetch("QDRANT_URL", "http://localhost:6333"))

client.collections.delete(collection_name: COLLECTION_NAME)

client.collections.create(
  collection_name: COLLECTION_NAME,
  vectors: {
    size: 1536,
    distance: "Cosine"
  }
)

# Dir["mainstream_content/chunked_json/*.json"].each do |path|
#   chunked_item = JSON.load_file(path)
#   actions = chunked_item["chunks"].flat_map do |chunk|
#     action = { index: { _id: chunk["id"] } }
#     document_data = chunked_item.slice(*%w[content_id locale base_path title])
#     chunk_data = chunk.slice(*%w[content_url heading_context html_content plain_content openai_embeddings digest])
#     [action, document_data.merge(chunk_data)]
#   end
#   client.bulk(index: INDEX_NAME, body: actions)
# end
