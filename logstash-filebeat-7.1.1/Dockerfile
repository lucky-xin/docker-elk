FROM docker.elastic.co/logstash/logstash:7.1.1

RUN rm -f /usr/share/logstash/pipeline/logstash.conf \
    && cd /bin/ \
    && logstash-plugin install logstash-codec-json_lines

#ADD pipeline/ /usr/share/logstash/pipeline/
ADD config/ /usr/share/logstash/config/
