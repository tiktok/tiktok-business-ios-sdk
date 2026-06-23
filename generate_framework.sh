#!/bin/bash

# Build static and dynamic TikTok Business SDK XCFrameworks for iOS devices
# and simulators.
#
# Usage:
#   ./generate_framework.sh            # Build with Release (default)
#   ./generate_framework.sh Release    # Build with Release
#   ./generate_framework.sh Debug      # Build with Debug
#
# Output:
#   Products/TikTokBusinessSDK/TikTokBusinessSDK.xcframework
#     Static XCFramework
#
#   Products/TikTokBusinessSDKDynamic/TikTokBusinessSDKDynamic.xcframework
#     Dynamic XCFramework
#
#   Products/generate_framework.log
#     Detailed build log; overwritten on every run
#
# The dynamic XCFramework's inner framework and module remain named
# TikTokBusinessSDK to support the SDK's mixed Objective-C and Swift sources.

set -euo pipefail

# Work dirname
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD_DIR="${WORK_DIR}/build"
ARCHIVE_DIR="${BUILD_DIR}/Archives"
PRODUCTS_DIR="${WORK_DIR}/Products"
LOG_FILE="${PRODUCTS_DIR}/generate_framework.log"

# Recreate the log file on every run.
mkdir -p "${PRODUCTS_DIR}"
rm -f "${LOG_FILE}"
touch "${LOG_FILE}"

# Print key progress to the terminal and append it to the detailed log.
log_step() {
  echo "$1" | tee -a "${LOG_FILE}"
}

CONFIGURATION="${1:-Release}"
PROJECT_NAME="TikTokBusinessSDK"
PROJECT_PATH="${WORK_DIR}/${PROJECT_NAME}.xcodeproj"

case "${CONFIGURATION}" in
  Debug|Release)
    ;;
  *)
    echo "Usage: $0 [Debug|Release]" | tee -a "${LOG_FILE}" >&2
    exit 1
    ;;
esac

log_step "Build configuration: ${CONFIGURATION}"
log_step "Detailed log: ${LOG_FILE}"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/TikTokBusinessSDK-products.XXXXXX")"

cleanup() {
  rm -rf "${BUILD_DIR}" "${STAGING_DIR}"
}
trap cleanup EXIT

# Clear old build and output products
rm -rf \
  "${BUILD_DIR}" \
  "${PRODUCTS_DIR}/TikTokBusinessSDK" \
  "${PRODUCTS_DIR}/TikTokBusinessSDKDynamic"
mkdir -p "${ARCHIVE_DIR}" "${PRODUCTS_DIR}"

COMMON_BUILD_SETTINGS=(
  "SKIP_INSTALL=NO"
  "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
  "CODE_SIGNING_ALLOWED=NO"
)

build_xcframework() {
  local scheme_name="$1"
  local output_name="$2"
  local product_name="$3"
  local module_name="$4"
  local install_dir="${STAGING_DIR}/${output_name}"
  local derived_data_dir="${BUILD_DIR}/DerivedData/${scheme_name}"
  local device_archive="${ARCHIVE_DIR}/${scheme_name}-iphoneos.xcarchive"
  local simulator_archive="${ARCHIVE_DIR}/${scheme_name}-iphonesimulator.xcarchive"

  mkdir -p "${install_dir}"

  log_step "Building ${output_name} for iOS..."
  if ! xcodebuild archive \
    -project "${PROJECT_PATH}" \
    -configuration "${CONFIGURATION}" \
    -scheme "${scheme_name}" \
    -destination "generic/platform=iOS" \
    -archivePath "${device_archive}" \
    -derivedDataPath "${derived_data_dir}" \
    "${COMMON_BUILD_SETTINGS[@]}" \
    "PRODUCT_NAME=${product_name}" \
    "PRODUCT_MODULE_NAME=${module_name}" >> "${LOG_FILE}" 2>&1; then
    log_step "Failed to build ${output_name} for iOS. See ${LOG_FILE}"
    return 1
  fi

  log_step "Building ${output_name} for iOS Simulator..."
  if ! xcodebuild archive \
    -project "${PROJECT_PATH}" \
    -configuration "${CONFIGURATION}" \
    -scheme "${scheme_name}" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "${simulator_archive}" \
    -derivedDataPath "${derived_data_dir}" \
    "${COMMON_BUILD_SETTINGS[@]}" \
    "PRODUCT_NAME=${product_name}" \
    "PRODUCT_MODULE_NAME=${module_name}" >> "${LOG_FILE}" 2>&1; then
    log_step "Failed to build ${output_name} for iOS Simulator. See ${LOG_FILE}"
    return 1
  fi

  log_step "Creating ${output_name}.xcframework..."
  if ! xcodebuild -create-xcframework \
    -framework "${device_archive}/Products/Library/Frameworks/${product_name}.framework" \
    -framework "${simulator_archive}/Products/Library/Frameworks/${product_name}.framework" \
    -output "${install_dir}/${output_name}.xcframework" >> "${LOG_FILE}" 2>&1; then
    log_step "Failed to create ${output_name}.xcframework. See ${LOG_FILE}"
    return 1
  fi

  # Avoid recursive header search paths picking up a previous target's build files.
  rm -rf "${derived_data_dir}" "${device_archive}" "${simulator_archive}"

  log_step "Created ${output_name}.xcframework"
}

# Static framework
build_xcframework \
  "TikTokBusinessSDK" \
  "TikTokBusinessSDK" \
  "TikTokBusinessSDK" \
  "TikTokBusinessSDK"

# Dynamic XCFramework. The inner framework keeps the existing bundle/module name
# because the SDK contains mixed Objective-C and Swift sources.
build_xcframework \
  "TikTokBusinessSDKDynamic" \
  "TikTokBusinessSDKDynamic" \
  "TikTokBusinessSDK" \
  "TikTokBusinessSDK"

mv "${STAGING_DIR}/TikTokBusinessSDK" "${PRODUCTS_DIR}/TikTokBusinessSDK"
mv "${STAGING_DIR}/TikTokBusinessSDKDynamic" "${PRODUCTS_DIR}/TikTokBusinessSDKDynamic"

log_step "Frameworks generated in ${PRODUCTS_DIR}"
