import os, pdb

from opensearchpy import OpenSearch

INDEX_NAME = "chunked_govuk_content"
HYBRID_SEARCH_PIPELINE = "knn_bm25_pipeline"
EMBEDDING_MODEL = "text-embedding-3-small"

client = OpenSearch(
    hosts=[os.getenv("OPENSEARCH_URL")],
    http_auth=(os.getenv("OPENSEARCH_USERNAME"), os.getenv("OPENSEARCH_PASSWORD")),
)

def print_results_summary(results):
    print(f"Query took: {results['took']}ms")
    # These may not exist for a miss I assume
    print(f"Max score: {results['hits']['max_score']}")
    print(f"Hits total: {results['hits']['total']}")
    print()
    for result in results['hits']['hits']:
        print(f"Score: {result['_score']}")
        print(result['_source']['content_url'])
        print(result['_source']['plain_content'])
        print()
