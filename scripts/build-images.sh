#!/bin/bash

# Build LuxFi branded Blockscout images
# Usage: ./build-images.sh [version]

VERSION=${1:-latest}
REGISTRY=${DOCKER_REGISTRY:-ghcr.io/luxfi}

echo "Building LuxFi branded Blockscout images..."
echo "Version: $VERSION"
echo "Registry: $REGISTRY"

# Build backend image
echo "Building backend image..."
docker build \
    --build-arg BLOCKSCOUT_VERSION=$VERSION \
    -t $REGISTRY/blockscout:$VERSION \
    -t $REGISTRY/blockscout:latest \
    -f ../docker/Dockerfile.luxfi \
    ..

# Tag for each network if needed
for NETWORK in lux zoo spc; do
    docker tag $REGISTRY/blockscout:$VERSION $REGISTRY/blockscout:$VERSION-$NETWORK
done

echo "Build complete!"
echo ""
echo "To push images:"
echo "docker push $REGISTRY/blockscout:$VERSION"
echo "docker push $REGISTRY/blockscout:latest"