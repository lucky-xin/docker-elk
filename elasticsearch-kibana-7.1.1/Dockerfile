FROM docker.elastic.co/elasticsearch/elasticsearch:7.1.1

RUN mkdir -p /usr/share/elasticsearch/plugins/ik/elasticsearch-analysis-ik-7.1.1 \
    && mkdir -p /usr/share/elasticsearch/plugins/pinyin/elasticsearch-analysis-pinyin-7.1.1

WORKDIR /docker-elasticsearch

COPY /elasticsearch-analysis-ik-7.1.1.tar.gz /usr/share/elasticsearch/plugins/ik
COPY /elasticsearch-analysis-pinyin-7.1.1.tar.gz /usr/share/elasticsearch/plugins/pinyin

RUN cd /usr/share/elasticsearch/plugins/ik   \
    && tar -zxvf /usr/share/elasticsearch/plugins/ik/elasticsearch-analysis-ik-7.1.1.tar.gz -C /usr/share/elasticsearch/plugins/ik  \
    && cd /usr/share/elasticsearch/plugins/pinyin   \
    && tar -zxvf /usr/share/elasticsearch/plugins/pinyin/elasticsearch-analysis-pinyin-7.1.1.tar.gz -C /usr/share/elasticsearch/plugins/pinyin