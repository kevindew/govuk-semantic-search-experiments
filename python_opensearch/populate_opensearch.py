from dotenv import load_dotenv
load_dotenv()

import json, pdb, glob

from opensearchpy import helpers as opensearch_helpers
from search import INDEX_NAME, client



# Delete index if it exists
if client.indices.exists(index=INDEX_NAME):
    client.indices.delete(index=INDEX_NAME)

# Create index with specified settings and mappings
client.indices.create(
    index=INDEX_NAME,
    body={
        "settings": {
            "index": {
                "knn": True
            }
        },
        "mappings": {
            "properties": {
                "content_id": {"type": "keyword"},
                "locale": {"type": "keyword"},
                "base_path": {"type": "keyword"},
                "document_type": {"type": "keyword"},
                "title": {"type": "text"},
                "content_url": {"type": "keyword"},
                "heading_context": {"type": "text"},
                "html_content": {"type": "text"},
                "plain_content": {"type": "text"},
                "openai_embedding": {
                    "type": "knn_vector",
                    "dimension": 1536,
                    "method": {
                        "name": "hnsw",
                        "space_type": "l2",
                        "engine": "faiss"
                    }
                },
                "digest": {"type": "keyword"}
            }
        }
    }
)

# populate index with data from JSON files
files = glob.glob("../mainstream_content/chunked_json/*.json")
for index, file_name in enumerate(files, 1):
    with open(file_name, "r") as file:
        chunked_item = json.load(file)
        actions = []
        base_item = {
            "_index": INDEX_NAME,
            "content_id": chunked_item["content_id"],
            "locale": chunked_item["locale"],
            "base_path": chunked_item["base_path"],
            "document_type": chunked_item["document_type"],
            "title": chunked_item["title"]
        }

        for chunk in chunked_item["chunks"]:

            document_data = {
                **base_item,
                "_id": chunk["id"],
                "content_url": chunk["content_url"],
                "heading_context": chunk["heading_context"],
                "html_content": chunk["html_content"],
                "plain_content": chunk["plain_content"],
                "openai_embedding": chunk["openai_embedding"],
                "digest": chunk["digest"],
            }

            actions.append(document_data)

        opensearch_helpers.bulk(client, actions)

    if index % 10 == 0:
        print(f"Imported {index} of {len(files)}")

print(f"All {len(files)} content items imported")
