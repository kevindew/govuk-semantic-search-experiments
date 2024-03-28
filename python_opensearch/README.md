# Python scripts for using OpenSearch

This contains a few scripts for populating and searching opensearch (expected to be a publicly available instance with credentials).

## To set-up

It is expected that you have pyenv or a similar tool to pick up the Python version from `.python-version`

Create and activate a venv:

```
python -m venv venv
source venv/bin/activate
```

Then install dependencies:

```
pip install
```

Finally make a copy of .env.example and populate that with an OpenAI key and the Opensearch URL and credentials. It is expected that this uses a remote OpenSearch instance and not the one in the docker-compose one directory up (as this code expects opensearch credentials) - it could be modified to use that.

```
cp .env.example .env
```

## To populate data

This will delete the index and create a new one, it will then populate it with data from `../mainstream_content/chunked_json/`. This file can be edited to adjust the index configuration.

This also creates a search pipeline for normalising the results of hybrid searches.

```
python populate_opensearch.py
```

## To search data.

There are a number of different scripts that perform different types of searches and print results. All can have the query set with a QUERY env var.

### Semantic (kNN) search

```
QUERY='tell me about maths' python semantic_search.py
```

### Lexical (BM25) search

```
QUERY='blood pressure' python lexical_search.py
```

### Hybrid search

This combines kNN and BM25 searches and uses a search pipeline to normalise the scores for comparability.

```
QUERY='tell me about IR35' python hybrid_search.py
```

### Boosted semantic search

This applies a penalty to particular document types.

```
QUERY='tell me about browsers' python semantic_search.py
```
