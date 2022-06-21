FROM docker.elastic.co/beats/filebeat:7.17.4

COPY filebeat.yml /usr/share/filebeat/filebeat.yml

USER root
RUN chown -R root:root /usr/share/filebeat
RUN chmod -R g+rX /usr/share/filebeat
RUN chmod -R go-w /usr/share/filebeat/filebeat.yml

USER filebeat
CMD filebeat
