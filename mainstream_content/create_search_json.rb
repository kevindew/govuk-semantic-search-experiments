require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "debug"
  gem "dotenv"
  gem "nokogiri"
  gem "ruby-openai"
end

require "debug"
require "digest"
require "dotenv/load"
require "json"
require "nokogiri"
require "openai"
require_relative "lib/html_hierarchical_chunker"

SOURCE_DIR = "content_store_json"
DESTINATION_DIR = "chunked_json"
CONTENT_IDS_TO_CHUNK = [
  "00627fe0-bbd9-497a-9466-556d9bb69234",
  "007b4e35-869f-4de1-b4ab-5345600bfc61",
  "00c99823-f7eb-4c82-8ee9-da83259aa9d8",
  "010bb297-f937-4fdb-9bfc-f0f0b1ace046"
]
OPENAI_EMBEDDING_MODEL = "text-embedding-3-small"

def serialize_content_item(content_item, chunks, openai_client)
  record_id = "#{content_item['content_id']}-#{content_item['locale']}"
  title = content_item["title"]
  base_path = content_item["base_path"]

  serialized_chunks = chunks.map.with_index do |chunk, index|
    chunk_id = "#{record_id}-#{index}"

    headers = chunk.select { |k, _| k.match?(/\Ah[2-6]\Z/) }.sort.map(&:last)
    # we can probably pull the actual id off the element but this is a quick fix
    content_url = if headers.any?
                    content_item["base_path"] + "#" + headers.last.downcase.gsub("\s", "-")
                  else
                    content_item["base_path"]
                  end

    html_content = chunk["html_content"]

    digest = Digest::SHA256.hexdigest(title + " " + headers.join(" ") + " " + html_content)
    parsed = Nokogiri::HTML::DocumentFragment.parse(html_content)
    heading_context = [title] + headers
    plain_content = (heading_context + [parsed.text]).join("\n")
    openai_response = openai_client.embeddings(
      parameters: { model: OPENAI_EMBEDDING_MODEL, input: plain_content }
    )
    openai_embeddings = openai_response.dig("data", 0, "embedding")


    {
      id: chunk_id,
      content_url:,
      heading_context:,
      html_content:,
      plain_content:,
      openai_embeddings:,
      digest:
    }
  end

  {
    id: record_id,
    content_id: content_item["content_id"],
    locale: content_item["locale"],
    base_path:,
    chunks: serialized_chunks,
    openai_embedding_model: OPENAI_EMBEDDING_MODEL
  }
end

Dir.mkdir(DESTINATION_DIR) unless Dir.exist?(DESTINATION_DIR)

openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"])

CONTENT_IDS_TO_CHUNK.each do |content_id|
  file_path = "#{SOURCE_DIR}/#{content_id}-en.json"

  unless File.exist?(file_path)
    puts "skipping #{content_id} as file (#{file_path}) does not exist"
    next
  end

  content_item = JSON.load_file(file_path)
  chunks = HtmlHierarchicalChunker.call(title: content_item["title"], html: content_item.dig("details", "body"))

  if chunks.empty?
    puts "skipping #{content_id} as no chunks were established."
    next
  end

  record = serialize_content_item(content_item, chunks, openai_client)

  filename = "#{content_id}-#{content_item['locale']}.json"
  File.write("#{DESTINATION_DIR}/#{filename}", JSON.pretty_generate(record))
end
