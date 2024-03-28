from dotenv import load_dotenv
load_dotenv()

import os, pdb

from openai import OpenAI

from search import INDEX_NAME, HYBRID_SEARCH_PIPELINE, EMBEDDING_MODEL, print_results_summary
from search import client as search_client

openai_client = OpenAI(api_key=os.getenv("OPENAI_ACCESS_TOKEN"))

query = os.getenv("QUERY", "Tell me about systolic pressure")

openai_response = openai_client.embeddings.create(
    input=query,
    model=EMBEDDING_MODEL
)

embedding = openai_response.data[0].embedding

results = search_client.search(
    index=INDEX_NAME,
    search_pipeline=HYBRID_SEARCH_PIPELINE,
    body = {
        "size": 5,
        "query": {
            "hybrid": {
                "queries" : [
                    {
                        "match": {
                            "plain_content": {
                                "query": query
                            }
                        }
                    },
                    {
                        "knn": {
                            "openai_embedding": {
                                "vector": embedding,
                                "k": 100,
                            }
                        }
                    }
                ]
            }
        },
        "_source": { "exclude": ["openai_embedding"] }
    }
)

print_results_summary(results)
