FROM docker.elastic.co/beats/filebeat:7.1.1

COPY filebeat.yml /usr/share/filebeat/filebeat.yml

USER root
RUN chown -R root:root /usr/share/filebeat
RUN chmod -R g+rX /usr/share/filebeat

USER filebeat
CMD filebeat
