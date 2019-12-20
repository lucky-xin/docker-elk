FROM elasticsearch:6.4.0
RUN yum install unzip
RUN mkdir -p /usr/share/elasticsearch/plugins/ik
RUN cd /usr/share/elasticsearch/plugins/ik && wget https://github.com/medcl/elasticsearch-analysis-ik/releases/download/v6.4.0/elasticsearch-analysis-ik-6.4.0.zip
RUN unzip /usr/share/elasticsearch/plugins/ik/elasticsearch-analysis-ik-6.4.0.zip -d /usr/share/elasticsearch/plugins/ik/