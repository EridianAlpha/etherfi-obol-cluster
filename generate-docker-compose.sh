#!/bin/bash

NODE_COUNT=${1:-0}
DOCKER_COMPOSE_FILE="docker-compose.yml"

generate_node_service() {
  local NODE_NUMBER=$1
  cat <<-EOF
  node-${NODE_NUMBER}:
    <<: *node-template
    environment:
      <<: *node-env
      CHARON_PRIVATE_KEY_FILE: /opt/charon/.charon/cluster/node${NODE_NUMBER}/charon-enr-private-key
      CHARON_LOCK_FILE: /opt/charon/.charon/cluster/node${NODE_NUMBER}/cluster-lock.json
      CHARON_JAEGER_SERVICE: node-${NODE_NUMBER}
      CHARON_P2P_EXTERNAL_HOSTNAME: node-${NODE_NUMBER}

  vc-${NODE_NUMBER}:
    image: consensys/teku:${TEKU_VERSION:-23.5.0}
    networks: [cluster]
    restart: unless-stopped
    command: |
      validator-client
      --data-base-path="/opt/data"
      --beacon-node-api-endpoint="http://node-${NODE_NUMBER}:3600"
      --metrics-enabled=true
      --metrics-host-allowlist="*"
      --metrics-interface="0.0.0.0"
      --metrics-port="8008"
      --validators-keystore-locking-enabled=false
      --network="${NETWORK}"
      --validator-keys="/opt/charon/validator_keys:/opt/charon/validator_keys"
      --validators-proposer-default-fee-recipient="${FEE_RECIPIENT}"
      --validators-graffiti="${GRAFFITI}"
    depends_on: [node-${NODE_NUMBER}]
    volumes:
      - ./vc-clients/teku:/opt/data
      - ./vc-clients/teku/run_validator.sh:/scripts/run_validator.sh
      - .charon/cluster/node${NODE_NUMBER}/validator_keys:/opt/charon/validator_keys
EOF
}

cat <<-'EOF' > $DOCKER_COMPOSE_FILE
version: "3.8"

x-node-base: &node-base
  image: obolnetwork/charon:${CHARON_VERSION:-v0.17.0}
  restart: unless-stopped
  networks: [cluster]
  depends_on: [relay]
  volumes:
    - ./.charon:/opt/charon/.charon/

x-node-env: &node-env
  CHARON_BEACON_NODE_ENDPOINTS: ${CHARON_BEACON_NODE_ENDPOINTS}
  CHARON_LOG_LEVEL: ${CHARON_LOG_LEVEL:-info}
  CHARON_LOG_FORMAT: ${CHARON_LOG_FORMAT:-console}
  CHARON_VALIDATOR_API_ADDRESS: 0.0.0.0:3600
  CHARON_MONITORING_ADDRESS: 0.0.0.0:3620
  CHARON_JAEGER_ADDRESS: 0.0.0.0:6831

x-node-template: &node-template
  <<: *node-base
  environment:
    <<: *node-env
    CHARON_P2P_RELAYS: ${CHARON_P2P_RELAYS}
    CHARON_P2P_TCP_ADDRESS: 0.0.0.0:${CHARON_TEKU_P2P_TCP_ADDRESS_PORT}
  ports:
    - ${CHARON_TEKU_P2P_TCP_ADDRESS_PORT}:${CHARON_TEKU_P2P_TCP_ADDRESS_PORT}/tcp

services:
  relay:
    <<: *node-base
    command: relay
    depends_on: []
    environment:
      <<: *node-env
      CHARON_HTTP_ADDRESS: 0.0.0.0:${CHARON_RELAY_PORT}
      CHARON_DATA_DIR: /opt/charon/relay
      CHARON_P2P_EXTERNAL_HOSTNAME: ${CHARON_P2P_EXTERNAL_HOSTNAME}
      CHARON_P2P_TCP_ADDRESS: 0.0.0.0:${CHARON_RELAY_P2P_TCP_ADDRESS_PORT}
    volumes:
      - ./relay:/opt/charon/relay:rw
    ports:
      - ${CHARON_RELAY_P2P_TCP_ADDRESS_PORT}:${CHARON_RELAY_P2P_TCP_ADDRESS_PORT}/tcp
      - ${CHARON_RELAY_PORT}:${CHARON_RELAY_PORT}/tcp
EOF

for (( NODE_NUMBER=0; NODE_NUMBER<=NODE_COUNT; NODE_NUMBER++ ))
do
  generate_node_service $NODE_NUMBER >> $DOCKER_COMPOSE_FILE
done

cat <<-'EOF' >> $DOCKER_COMPOSE_FILE
  prometheus:
    image: prom/prometheus:${PROMETHEUS_VERSION:-v2.41.0}
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    networks: [cluster]

  grafana:
    image: grafana/grafana:${GRAFANA_VERSION:-9.3.2}
    depends_on: [prometheus]
    volumes:
      - ./monitoring/grafana/datasource.yml:/etc/grafana/provisioning/datasources/datasource.yml
      - ./monitoring/grafana/dashboards.yml:/etc/grafana/provisioning/dashboards/datasource.yml
      - ./monitoring/grafana/grafana.ini:/etc/grafana/grafana.ini:ro
      - ./monitoring/grafana/dashboards:/etc/dashboards
    networks: [cluster]
    ports:
      - "${MONITORING_PORT_GRAFANA}:3000"

  node-exporter:
    image: prom/node-exporter:${NODE_EXPORTER_VERSION:-v1.5.0}
    networks: [cluster]

  jaeger:
    image: jaegertracing/all-in-one:${JAEGAR_VERSION:-1.41.0}
    networks: [cluster]

networks:
  cluster:
EOF