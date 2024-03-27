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
OPENAI_EMBEDDING_MODEL = "text-embedding-3-small"
EMBEDDING_BATCH_TOKEN_SIZE = 7500

def chunks_for_parts(content_item)
  content_item.dig("details", "parts").flat_map do |part|
    # we don't do anything with the title
    chunks = HtmlHierarchicalChunker.call(title: "", html: part["body"])
    base_url = content_item["base_path"] + "/" + part["slug"]

    chunks.map do |chunk|
      headers = headers_from_chunk(chunk)
      content_url = base_url
      content_url += "#" + guess_header_id(headers.last) if headers.any?

      {
        headers: headers,
        content_url:,
        html_content: chunk["html_content"]
      }
    end
  end
end

def chunks_for_transaction(content_item)
  # copied from https://github.com/alphagov/content-data-api/blob/main/app/domain/etl/edition/content/parsers/transaction.rb
  html_parts = []
  html_parts << content_item.dig("details", "introductory_paragraph")
  html_parts << content_item.dig("details", "more_information")

  chunks_for_html_string(html_parts.compact.join(" "), content_item["base_path"])
end

def chunks_for_html_string(html, base_path)
  chunks = HtmlHierarchicalChunker.call(title: "", html:)

  chunks.map do |chunk|
    headers = headers_from_chunk(chunk)
    content_url = base_path
    content_url += "#" + guess_header_id(headers.last) if headers.any?

    {
      headers: headers,
      content_url:,
      html_content: chunk["html_content"]
    }
  end
end

def serialize_content_item(content_item, formatted_chunks, openai_client)
  record_id = "#{content_item['content_id']}-#{content_item['locale']}"
  title = content_item["title"]

  serialized_chunks = formatted_chunks.map.with_index do |chunk, index|
    chunk_id = "#{record_id}-#{index}"

    headers = chunk[:headers]
    html_content = chunk[:html_content]

    digest = Digest::SHA256.hexdigest(title + " " + headers.join(" ") + " " + html_content)
    parsed = Nokogiri::HTML::DocumentFragment.parse(html_content)
    heading_context = [title] + headers
    plain_content = (heading_context + [parsed.text]).join("\n")
    # openai_response = openai_client.embeddings(
    #   parameters: { model: OPENAI_EMBEDDING_MODEL, input: plain_content }
    # )
    # openai_embedding = openai_response.dig("data", 0, "embedding")

    {
      id: chunk_id,
      content_url: chunk[:content_url],
      heading_context:,
      html_content:,
      plain_content:,
      digest:
    }
  end

  {
    id: record_id,
    content_id: content_item["content_id"],
    locale: content_item["locale"],
    base_path: content_item["base_path"],
    chunks: apply_openai_embedding_to_chunks(serialized_chunks, openai_client),
    document_type: content_item["document_type"],
    openai_embedding_model: OPENAI_EMBEDDING_MODEL
  }
end

def headers_from_chunk(chunk)
  chunk.select { |k, _| k.match?(/\Ah[2-6]\Z/) }.sort.map(&:last)
end

def guess_header_id(header)
  header.downcase.gsub(/[^0-9a-z ]/i, "").gsub("\s", "-")
end

# Batch together a call to openai to get multiple embeddings at once
def apply_openai_embedding_to_chunks(chunks, openai_client)
  # split these chunks into an array of groups that roughly fit into OpenAI token limits
  grouped_chunks = chunks.each_with_object([]) do |chunk, memo|
    current_tokens = OpenAI.rough_token_count(chunk[:plain_content])

    if current_tokens >= EMBEDDING_BATCH_TOKEN_SIZE || memo.last.nil?
      memo.append([chunk])
      next
    end

    used_tokens = (memo.last).inject(0) { |memo, chunk| memo + OpenAI.rough_token_count(chunk[:plain_content]) }

    if (used_tokens + current_tokens) > EMBEDDING_BATCH_TOKEN_SIZE
      # create a new group
      memo.append([chunk])
    else
      # add it to the last group
      memo.last.append(chunk)
    end
  end

  grouped_chunks.each do |grouping|
    to_embedding = grouping.map { |chunk| chunk[:plain_content] }
    openai_response = openai_client.embeddings(
      parameters: { model: OPENAI_EMBEDDING_MODEL, input: to_embedding }
    )

    openai_response.dig("data").each do |openai_data|
      grouping[openai_data["index"]][:openai_embedding] = openai_data["embedding"]
    end
  end

  chunks
end

Dir.mkdir(DESTINATION_DIR) unless Dir.exist?(DESTINATION_DIR)

openai_client = OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"])

files = Dir["content_store_json/*.json"]

total_processed = 0
start_time = Time.now

# use 50 threads for faster speed
files.each_slice(50).each do |files_chunk|
  threads = files_chunk.map do |file_path|
    Thread.new do
      content_item = JSON.load_file(file_path)

      chunks = case content_item["document_type"]
               when "answer", "help"
                 # body content
                 chunks_for_html_string(content_item.dig("details", "body"), content_item["base_path"])
               when "guide"
                 # parts content
                 chunks_for_parts(content_item)
               when "transaction"
                 # custom
                 chunks_for_transaction(content_item)
               else # completed_transaction, local transaction, place, service_sign_in, simple_smart_answer
                 # skip - not worth indexing
                 next
               end

      record = serialize_content_item(content_item, chunks, openai_client)

      filename = "#{content_item["content_id"]}-#{content_item['locale']}.json"
      File.write("#{DESTINATION_DIR}/#{filename}", JSON.pretty_generate(record))
    end
  end

  threads.each(&:join)
  total_processed += files_chunk.count

  puts "processed #{total_processed} of #{files.count} in #{Time.now - start_time} seconds"
end
