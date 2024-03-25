#!/bin/bash
# Script to add Kustomization to Helm output

set -euo pipefail

# make temporary working directory for rendering helm + kustomize
workdir=$(mktemp -d)
cd $workdir

echo "# Kustomize"
echo "# Kustomize input dir: $ENV_BASE_DIR/kustomize"

cp -r $ENV_BASE_DIR/kustomize/* .

# write helm output from stdin to a dedicated file
cat > helm-output.yaml

kustomize build --enable-alpha-plugins --enable-exec .

echo "# Kustomize done"

cd $HOME

rm -rf $workdir
