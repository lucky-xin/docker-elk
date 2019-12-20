docker run -d --name=datainsights-es-datanodeX -p 9200:9200 -p 9300:9300 -v elasticsearch-datanode.yml:/usr/share/elasticsearch/config/elasticsearch.yml -v datainsights-es-datanode:/usr/share/elasticsearch/data cenzhongman/elasticsearch-ik

https://www.elastic.co/guide/cn/elasticsearch/guide/current/replica-shards.html

tar zcf elasticsearch-analysis-ik-7.1.0.tar.gz elasticsearch-analysis-ik-7.1.0
tar zcf elasticsearch-analysis-pinyin-7.1.1.tar.gz elasticsearch-analysis-pinyin-7.1.1

https://www.elastic.co/guide/en/elasticsearch/reference/7.1/docker.html