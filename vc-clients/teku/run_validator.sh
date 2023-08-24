#!/bin/sh
validator-client \
  --data-base-path="/opt/data" \
  --beacon-node-api-endpoint="http://node-$1:3600" \
  --metrics-enabled=true \
  --metrics-host-allowlist="*" \
  --metrics-interface="0.0.0.0" \
  --metrics-port="8008" \
  --validators-keystore-locking-enabled=false \
  --network="${NETWORK}" \
  --validator-keys="/opt/charon/validator_keys:/opt/charon/validator_keys" \
  --validators-proposer-default-fee-recipient="${FEE_RECIPIENT}" \
  --validators-graffiti="${GRAFFITI}"
