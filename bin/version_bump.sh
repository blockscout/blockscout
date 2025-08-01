#!/bin/bash

# Path to the mix.exs file
MIX_FILES=(
    "$(pwd)/mix.exs"
    "$(pwd)/apps/block_scout_web/mix.exs"
    "$(pwd)/apps/explorer/mix.exs"
    "$(pwd)/apps/indexer/mix.exs"
    "$(pwd)/apps/ethereum_jsonrpc/mix.exs"
    "$(pwd)/apps/utils/mix.exs"
    "$(pwd)/apps/nft_media_handler/mix.exs"
)
CONFIG_FILE="$(pwd)/rel/config.exs"
DOCKER_COMPOSE_FILE="$(pwd)/docker-compose/docker-compose.yml"
DOCKER_COMPOSE_NO_SERVICES_FILE="$(pwd)/docker-compose/no-services.yml"
MAKE_FILE="$(pwd)/docker/Makefile"
WORKFLOW_FILES=($(find "$(pwd)/.github/workflows" -type f \( -name "pre-release*" -o -name "release*" -o -name "publish-regular-docker-image-on-demand*" -o -name "publish-docker-image-*" -o -name "generate-swagger*" \)))
METADATA_RETRIEVER_FILE="$(pwd)/apps/explorer/lib/explorer/token/metadata_retriever.ex"

# Function to bump version
bump_version() {
    local type=$1
    local custom_version=$2

    # Extract the current version
    MIX_FILE="${MIX_FILES[0]}"
    current_version=$(grep -o 'version: "[0-9]\+\.[0-9]\+\.[0-9]\+"' "$MIX_FILE" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    echo "Current version: $current_version"

    # Split the version into its components
    IFS='.' read -r -a version_parts <<< "$current_version"

    # Check if the --patch flag is provided
    if [[ "$type" == "--patch" ]]; then
        # Increment the patch version
        version_parts[2]=$((version_parts[2] + 1))
    elif [[ "$type" == "--minor" ]]; then
        # Increment the minor version and reset the patch version
        version_parts[1]=$((version_parts[1] + 1))
        version_parts[2]=0
    elif [[ "$type" == "--major" ]]; then
        # Increment the major version and reset the minor and patch versions
        version_parts[0]=$((version_parts[0] + 1))
        version_parts[1]=0
        version_parts[2]=0
    elif [[ "$type" == "--update-to-version" ]]; then
        # Apply the version from the 3rd argument
        if [[ -z "$2" ]]; then
            echo "Error: No version specified for --update-to-version."
            exit 1
        fi
        new_version="$custom_version"
        IFS='.' read -r -a version_parts <<< "$new_version"
    else
        echo "No --patch flag provided. Exiting."
        exit 1
    fi

    # Join the version parts back together
    new_version="${version_parts[0]}.${version_parts[1]}.${version_parts[2]}"

    # Replace the old version with the new version in the mix.exs files
    for MIX_FILE in "${MIX_FILES[@]}"; do
        sed -i '' "s/version: \"$current_version\"/version: \"$new_version\"/" "$MIX_FILE"
    done

    sed -i '' "s/version: \"$current_version\"/version: \"$new_version\"/" "$CONFIG_FILE"
    sed -i '' "s/RELEASE_VERSION: $current_version/RELEASE_VERSION: $new_version/" "$DOCKER_COMPOSE_FILE"
    sed -i '' "s/RELEASE_VERSION: $current_version/RELEASE_VERSION: $new_version/" "$DOCKER_COMPOSE_NO_SERVICES_FILE"
    sed -i '' "s/RELEASE_VERSION ?= '$current_version'/RELEASE_VERSION ?= '$new_version'/" "$MAKE_FILE"

    # Replace the old version with the new version in the GitHub workflows files
    for WORKFLOW_FILE in "${WORKFLOW_FILES[@]}"; do
        sed -i '' "s/RELEASE_VERSION: $current_version/RELEASE_VERSION: $new_version/" "$WORKFLOW_FILE"
    done

    sed -i '' "s/\"blockscout-$current_version\"/\"blockscout-$new_version\"/" "$METADATA_RETRIEVER_FILE"

    echo "Version bumped from $current_version to $new_version"
}

# Call the function
bump_version "$1" "$2"
