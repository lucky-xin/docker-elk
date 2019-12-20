FROM docker.elastic.co/logstash/logstash:6.6.0

RUN rm -f /usr/share/logstash/pipeline/logstash.conf \
    && cd /bin/ \
    && logstash-plugin install logstash-codec-json_lines

#ADD pipeline/ /usr/share/logstash/pipeline/
ADD config/ /usr/share/logstash/config/
