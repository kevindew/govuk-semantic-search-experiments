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

Finally make a copy of .env.example and populate that with an OpenAI key and the Opensearch URL and credentials.

```
cp .env.example .env
```

## To populate data

This will delete the index and create a new one and then populate it with data from `../mainstream_content/chunked_json/`. This file can be edited to adjust the index configuration.

```
python populate_opensearch.py
```




