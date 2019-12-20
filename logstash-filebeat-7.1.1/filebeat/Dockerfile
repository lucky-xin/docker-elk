FROM docker.elastic.co/beats/filebeat:7.1.1

COPY /filebeat/filebeat.yml /usr/share/filebeat/filebeat.yml
USER root
RUN chown root /usr/share/filebeat/filebeat.yml \
    && chmod go-w /usr/share/filebeat/filebeat.yml  \
    && mkdir -p /datainsights-mysql/data    \
    && mkdir -p /var/datainsights-logs
