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

client.collections.delete(collection_name: COLLECTION_NAME) # This seems to be idempotent

client.collections.create(
  collection_name: COLLECTION_NAME,
  vectors: {
    size: 1536,
    distance: "Cosine"
  }
)

id = 0
Dir["mainstream_content/chunked_json/*.json"].each do |path|
  chunked_item = JSON.load_file(path)
  points = chunked_item["chunks"].map do |chunk|
    document_data = chunked_item.slice(*%w[content_id locale base_path title])
    chunk_data = chunk.slice(*%w[content_url heading_context html_content plain_content digest])

    # we can have an int or a uuid as the id, both are a bit annoying as we'd want
    # something we can generate from the chunk. I went for an ascending int just
    # so they're easier to guess for checking.
    {
      id: id += 1,
      vector: chunk["openai_embedding"],
      payload: document_data.merge(chunk_data)
    }
  end

  # doesn't seem to raise an exception if this errors
  client.points.upsert(
    collection_name: COLLECTION_NAME,
    points:,
  )
end
