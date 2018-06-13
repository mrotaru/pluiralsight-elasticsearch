# setup .netrc with username and password, or run image without auth

# show indices
http :9200/_cat/indices 

# add docs to index
http PUT :9200/products/mobiles/1 id=1 model="Nikon 1" memory=32

# retrieve whole doc
http :9200/products/mobiles/1

# retrieve partial doc
http :9200/products/mobiles/1?_source=id,memory

# update whole doc - same as adding to the index
http PUT :9200/products/mobiles/1 id=1 model="Nikon 1" memory=64

# update partial doc
http POST :9200/products/mobiles/1/_update doc:='{"memory": 64}'

# update with script
http POST :9200/products/mobiles/1/_update script='ctx._source.generation += 1'

# delete doc
http DELETE :9200/products/mobiles/1

# delete index
http DELETE :9200/products

# bullk
http :9200/_mget docs:='[{ "_index": "products", "_type": "mobiles", "_id": "1" }]'
http :9200/products/_mget docs:='[{ "_type": "mobiles", "_id": "1" }]'
http :9200/products/mobiles/_mget docs:='[{ "_id": "1" }]'
http :9200/products/mobiles/_mget docs:='[{ "_id": "1" }, { "_id": "2" }]'
# with ndjson, we can use the _bulk endpoint to perform operations on multiple docs: create, delete, update

# Search
# ------

# when you sort, no relevance score
# no pagination, searches are stateless
http :9200/customers/_search q==address:wyoming sort==age:desc --print b | jq '.hits.total'
http :9200/customers/_search q==address:wyoming sort==age:desc from==10 size==2 --print b | jq '.hits.total'

# search multiple indices
http :9200/customers,products/_search q==foo

# specify request in body
http :9200/customers/_search query:='{"match_all": {}}' sort:='{"age": { "order": "desc" } }' size:=20

# search terms - 'name' field must contain 'gates' - case insensitive by default
http :9200/customers/_search query:='{"term": { "name": "gates"} }'

# ommit _source, or the document body; only see document id's in results
http :9200/customers/_search query:='{"term": { "name": "gates"} }' _source:=false

# selecting which fields are included in the returned results
http :9200/customers/_search query:='{"term": { "name": "gates"} }' _source:='"ad*"'
http :9200/customers/_search query:='{"term": { "name": "gates"} }' _source:='["ad*", "*na*"]'
http :9200/customers/_search query:='{"term": { "name": "gates"} }' _source:='{"include": ["ad*", "*na*"], "excludes": ["friends"]}'

# full text search - using `match` in the `query` object
http :9200/customers/_search query:='{"match": { "name": "webster" } }'
http :9200/customers/_search query:='{"match": { "name": { "query": "webster michael", "operator": "or" } } }'
http :9200/customers/_search query:='{"match_phrase": { "address": "tompkins place" } }' # full phrase match
http :9200/customers/_search query:='{"match_phrase_prefix": { "name": "ma" } }' # search in the begginning

# TF/IDF
# - term frequency - in the scored doc's relevant fields - more often, more relevant
# - inverse document frequency - in all indexed docs - more often, less relevant
# - field-length norm - more words in a field -> less relevant

# `common` and `cutoff_frequency` - use when you have common terms
http :9200/customers/_search query:='{
  "common": {
    "personal": {
      "query": "wyoming street",
      "cutoff_frequency": 0.001
    }
  }
}'

# if multiple `must` clauses, all must match
# if multiple `should`, only one can match; but multiple matches means higher relevance
# can use 'boost' to make terms more relevant

# can use `must`, `must_not`, `should`
http :9200/customers/_search query:='{
"bool": {
  "must": [
    { "match": { "address": "wyoming" } },
    { "match": { "address": "street" } }
  ]
}
}' _source:='"address"'

# when excluding terms (with `must_not`), score is constant
http :9200/customers/_search query:='{
"bool": {
  "must_not": [
    { "match": { "address": "wyoming" } },
    { "match": { "address": "street" } }
  ]
}
}' _source:='"address"'

# using `boost`
http :9200/customers/_search query:='{
"bool": {
  "should": [
    { "term": { "address": { "value": "wyoming" } } },
    { "term": { "address": { "value": "street", "boost": 2.0 } } }
  ]
}
}' _source:='"address"'

# filtering
http :9200/customers/_search query:='{
"bool": {
  "must": { "match_all": {} },
  "filter": {
    "range": { "age": { "gte": 20, "lte": 30 } }
  }
}
}'

# combine filtering and querying
http :9200/customers/_search query:='{
"bool": {
  "must": { "match": { "address": "wyoming" } },
  "filter": [
    { "term": { "gender": "female" } },
    { "range": { "age": { "lte": 20 } } }
   ]
}
}'

# Aggregations
# ------------

http :9200/customers/_search size:=0 aggs:='
{
  "avg_age": {
     "avg": { "field": "age" }
  }
}'

# combine queries with aggregations
http :9200/customers/_search size:=0 aggs:='
{
  "avg_age": {
     "avg": { "field": "age" }
  }
}' qyery:='
{
  "bool": {
    "must": { "match": { "address": "wyoming" } }
  }
}'

# buckets
http :9200/customers/_search size:=0 aggs:='
{
  "age_bucket": {
    "terms": { "field": "age" }
  }
}'

# document counts are approximate
# https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-terms-aggregation.html

