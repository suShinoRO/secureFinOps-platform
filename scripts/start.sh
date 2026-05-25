#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Starting infrastructure..."
cd "$ROOT_DIR/infra/environments/local"
terraform init -input=false
terraform apply -auto-approve

echo "==> Starting application..."
cd "$ROOT_DIR"
set -a
source "$ROOT_DIR/.env"
set +a

mvn spring-boot:run 