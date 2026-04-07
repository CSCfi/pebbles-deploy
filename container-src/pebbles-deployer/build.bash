#!/usr/bin/env bash

# A simple script to build pebbles-deployer locally
# The default container image name is `cscfi/pebbles-deployer:latest`
# How to run: ./build.bash <container_image_name_and_tag>

set -ex

# if environment variable DOCKER_EXECUTABLE is not set, use docker as default
DOCKER_EXECUTABLE="${DOCKER_EXECUTABLE:-docker}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_AND_TAG=${1-cscfi/pebbles-deployer:latest}
EXTRA_ARGS=${EXTRA_ARGS:-}

# Create a temp directory for docker build context
STAGE=$(mktemp -d)

# Build tarball of the repo (only tracked files)
(
  # skip metadata on Mac
  tar_args=""
  if [[ "$(uname -s)" == "Darwin" ]]; then
    tar_args="--no-xattr --no-mac-metadata"
  fi

  cd "$SCRIPT_DIR/../.."
  git ls-files -z | tar --null $tar_args -czf "$STAGE/pebbles-deploy-src.tar.gz" -T -
)

# Add version file
(
  cd "$SCRIPT_DIR/../.."
  COMMIT=$(git rev-parse HEAD)
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  DATE=$(git show -s --format=%cI HEAD)
  NUM_DIRTY=$(( $(git status --porcelain | wc -l) ))
  cat > "$STAGE/.version_info" <<EOF
GIT_COMMIT=$COMMIT
GIT_BRANCH=$BRANCH
GIT_COMMIT_DATE=$DATE
GIT_NUM_DIRTY=$NUM_DIRTY
EOF
)

# Copy only the deployer Dockerfile + scripts into staging area
cp -r "$SCRIPT_DIR/." "$STAGE/"

$DOCKER_EXECUTABLE build \
    --pull=true \
    -t $IMAGE_AND_TAG \
    -f "$STAGE/Dockerfile" \
    ${EXTRA_ARGS} \
    "$STAGE"

rm -rf "$STAGE"
