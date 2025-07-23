FROM confluentinc/cp-kafka-connect-base:7.8.0

USER root
RUN microdnf update && microdnf install -y curl sqlite && microdnf clean all

RUN mkdir -p /usr/share/confluent-hub-components

# Install JDBC connector
RUN confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:10.7.4

# Download SQLite JDBC driver
RUN cd /usr/share/confluent-hub-components && \
    curl -O https://github.com/xerial/sqlite-jdbc/releases/download/3.44.1.0/sqlite-jdbc-3.44.1.0.jar

# Copy initialization script
COPY init-sqlite.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-sqlite.sh

USER appuser
ENTRYPOINT ["/etc/confluent/docker/run"]
