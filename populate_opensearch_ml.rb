require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "debug"
  gem "opensearch-ruby"
end

require "json"
require "opensearch-ruby"

INDEX_NAME = "chunked_govuk_content"
MODEL_GROUP_NAME = "model group"
EMBEDDING_MODEL = "huggingface/sentence-transformers/msmarco-distilbert-base-tas-b"

client = OpenSearch::Client.new(url: ENV.fetch("OPENSEARCH_URL", "http://localhost:9202"))

#
# Configure cluster
#

# hopwfully these can be set-up by an env var - I couldn't work out how.
client.http.put("_cluster/settings", body: {
  persistent: {
    plugins: {
      ml_commons: {
        only_run_on_ml_node: false,
        model_access_control_enabled: true,
        native_memory_threshold: 99
      }
    }
  }
})

#
# Register model group
#
model_group_search = client.http.post(
  "_plugins/_ml/model_groups/_search",
  body: { query: { match: { name: MODEL_GROUP_NAME } } }
)

model_group_id = model_group_search.dig("hits", "hits", 0, "_id")

if model_group_id
  puts "Model group (#{model_group_id}) already created"
else
  model_group_registration = client.http.post(
    "_plugins/_ml/model_groups/_register",
    body: { name: MODEL_GROUP_NAME },
  )

  model_group_id = model_group_registration["model_group_id"]

  puts "Model group (#{model_group_id}) created"
end

#
# Register model
#

model_search = client.http.post(
  "_plugins/_ml/models/_search",
  body: { query: { match: { name: EMBEDDING_MODEL } } }
)
debugger # DEBUG @kevindew

model_id = model_search.dig("hits", "hits", 0, "_source", "model_id")

if model_id
  model = client.http.get("_plugins/_ml/models/#{model_id}")

  if model["model_state"] == "DEPLOYED"
    response = client.http.post("_plugins/_ml/models/#{model_id}/_undeploy")
  end

  puts "Model (#{model_id}) already exists, deleting"

  client.http.delete("_plugins/_ml/models/#{model_id}")
end

model_registration = client.http.post(
  "_plugins/_ml/models/_register?deploy=true",
  body: {
    name: EMBEDDING_MODEL,
    version: "1.0.1",
    model_group_id:,
    model_format: "TORCH_SCRIPT"
  }
)

task_id = model_registration["task_id"]
puts "Model being created with task: #{task_id}"

model_id = nil

loop do
  task = client.http.get("_plugins/_ml/tasks/#{task_id}")

  if task["state"] == "CREATED"
    sleep(5)
    puts "Waiting for model completion"
  elsif task["state"] == "COMPLETED"
    model_id = task["model_id"]
    puts "Model (#{model_id}) created"
    break
  else
    raise "Unexpected task status: #{task['state']}"
  end
end


# client.indices.delete(index: INDEX_NAME) if client.indices.exists?(index: INDEX_NAME)
#
# client.indices.create(
#   index: INDEX_NAME,
#   body: {
#     settings: {
#       index: {
#         knn: true
#       }
#     },
#     mappings: {
#       properties: {
#         content_id: { type: "keyword" },
#         locale: { type: "keyword" },
#         base_path: { type: "keyword" },
#         content_url: { type: "keyword" },
#         title: { type: "text" },
#         heading_context: { type: "text" },
#         html_content: { type: "text" },
#         plain_content: { type: "text" },
#         openai_embedding: {
#           type: "knn_vector",
#           dimension: 1536,
#           method: {
#             name: "hnsw",
#             space_type: "l2",
#             engine: "faiss"
#           }
#         },
#         digest: { type: "keyword" }
#       }
#     }
#   }
# )
#
# Dir["mainstream_content/chunked_json/*.json"].each do |path|
#   chunked_item = JSON.load_file(path)
#   actions = chunked_item["chunks"].flat_map do |chunk|
#     action = { index: { _id: chunk["id"] } }
#     document_data = chunked_item.slice(*%w[content_id locale base_path title])
#     chunk_data = chunk.slice(*%w[content_url heading_context html_content plain_content openai_embedding digest])
#     [action, document_data.merge(chunk_data)]
#   end
#   client.bulk(index: INDEX_NAME, body: actions)
# end
