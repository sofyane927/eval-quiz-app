#!/usr/bin/env bash
set -euo pipefail

docker save "${1:?Provide a local image tag}" | docker run --rm -i --entrypoint sh \
  aquasec/trivy@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb \
  -ec 'cat > /tmp/image.tar && trivy image --input /tmp/image.tar --scanners vuln --severity CRITICAL --exit-code 1 --no-progress'
