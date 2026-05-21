#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Stopping application..."
pkill -f "spring-boot:run" 2>/dev/null || echo "Application not running"

echo "==> Destroying infrastructure..."
cd "$ROOT_DIR/infra/environments/local"
terraform destroy -auto-approve

echo "==> Done. All resources destroyed."