# Experimenting with Semantic Search on GOV.UK content

This repository contains a number of experimental scripts that explore indexing mainstream GOV.UK content in different semantic search tools.

The most polished parts of this are [./mainstream_content](mainstream_content/) and [./python_opensearch](python_opensearch/), while these scripts in the root directory are just aspects of experiments.

## To use

There is a docker compose file to run database engines. You can start them all with `docker-compose up` or individual ones e.g. `docker-compose up opensearch-2`.

You can populate those databases with data using the `populate_*.rb` scripts. E.g. `ruby populate_opensearch.rb`.

You can run queries and typically enter a debugger to see the results with the `searching_*.rb` scripts. E.g `ruby searching_opensearch.rb`

Do bear in mind that a bunch of these scripts are half finished.

