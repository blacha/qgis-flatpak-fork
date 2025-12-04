#!/bin/bash
set -e

MANIFEST="nz.govt.linz.qgis.json"
BUILD_DIR="build-dir"
STATE_DIR=".flatpak-builder"

# Ensure jq is available
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Aborting."
    exit 1
fi

echo "Extracting modules from manifest..."

# Get nested modules of 'qgis'
# The modules array can contain objects or strings (paths to json files)
# We need to extract the name from each.
# Get nested modules of 'qgis'
# Extract module names from the manifest using grep and sed
# Assumes lines look like: "modules/arrow.json",
NESTED_MODULES=$(grep '"modules/.*\.json"' "$MANIFEST" | sed -E 's/.*"modules\/(.*)\.json".*/\1/')

TOP_LEVEL_MODULES=$(jq -r '.modules[].name' "$MANIFEST")

echo "Starting incremental build..."

# Function to build a module
build_module() {
    local module=$1
    echo "::group::Building module: $module"
    echo "----------------------------------------------------------------"
    echo "Building module: $module"
    echo "----------------------------------------------------------------"
    
    # We use --keep-build-dirs because we want to manually control cleanup, 
    # but --delete-build-dirs is safer if we trust flatpak-builder.
    # However, to be absolutely sure we reclaim space, we'll rm -rf the build subdir.
    
    # Explicitly clean build dir to avoid "Directory not empty" errors
    rm -rf "$BUILD_DIR"

    flatpak-builder \
        --force-clean \
        --stop-at="$module" \
        --state-dir="$STATE_DIR" \
        --disable-rofiles-fuse \
        "$BUILD_DIR" \
        "$MANIFEST"

    echo "Cleaning up build artifacts for $module..."
    # Clean up the specific build directory for this module to save space
    # The build dir structure is usually .flatpak-builder/build/$module
    if [ -d "$STATE_DIR/build/$module" ]; then
        rm -rf "$STATE_DIR/build/$module"
        echo "Removed $STATE_DIR/build/$module"
    fi
    
    echo "::endgroup::"
}

# 1. Build nested modules of qgis
for mod in $NESTED_MODULES; do
    build_module "$mod"
done

# 2. Build top-level modules
for mod in $TOP_LEVEL_MODULES; do
    # If it's 'qgis', we've already built its dependencies. Now build the module itself.
    build_module "$mod"
done

echo "----------------------------------------------------------------"
echo "Build complete!"
echo "----------------------------------------------------------------"
