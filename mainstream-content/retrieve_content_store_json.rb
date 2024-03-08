require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "debug"
  gem "gds-api-adapters"
  gem "rack" # needed due to: https://github.com/alphagov/gds-api-adapters/pull/1238
end

require "debug"
require "gds-api-adapters"

DESTINATION_DIR = "content_store_json"
Dir.mkdir(DESTINATION_DIR) unless Dir.exist?(DESTINATION_DIR)

base_paths = File.read("base_paths.txt").split("\n")
content_store = GdsApi::ContentStore.new("https://www.gov.uk/api", timeout: 30)

existing_files = Dir.entries(DESTINATION_DIR).select { |filename| filename.end_with?(".json") }

created = base_paths.filter_map do |base_path|
  content_item = content_store.content_item(base_path)
  if content_item["locale"] != "en"
    puts "Skipping #{base_path} due to non-English content"
    next
  end

  if content_item["publishing_app"] != "publisher"
    puts "Skipping #{base_path} due to #{content_item['publishing_app']} publishing app"
    next
  end

  filename = "#{content_item['content_id']}-#{content_item['locale']}.json"

  File.write("#{DESTINATION_DIR}/#{filename}", JSON.pretty_generate(content_item.to_h))

  filename
rescue GdsApi::HTTPErrorResponse => e
  puts "failed to fetch #{base_path}, received #{e.code}"
end

to_delete = existing_files - created
to_delete.each do |filename|
  File.delete("#{DESTINATION_DIR}/#{filename}")
  puts "Deleted #{filename} as a new version was not available"
end

