# This container is used by pebbles as a sidecar pod for sessions.
FROM docker.io/nginxinc/nginx-unprivileged:1.31-alpine

# Permissions for OKD where the process UID is decided by the system but the process runs with group id 0
USER 0
RUN chmod -R g=u /var/cache/nginx /etc/nginx
USER 101
