from dotenv import load_dotenv
load_dotenv()

import os, pdb

from search import INDEX_NAME, print_results_summary
from search import client as search_client

query = os.getenv("QUERY", "Tell me about systolic pressure")

results = search_client.search(
    index = INDEX_NAME,
    body = {
        "size": 5,
        "query": {
            "match": {
                "plain_content": {
                    "query": query
                }
            }
        },
        "_source": { "exclude": ["openai_embedding"] }
    }
)

print_results_summary(results)
