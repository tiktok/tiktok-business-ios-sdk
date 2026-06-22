#!/bin/bash

set -e

# Work dirname
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIGURATION="Release"
SDK_NAME="TikTokBusinessSDK"
PROJECT_PATH="${WORK_DIR}/${SDK_NAME}.xcodeproj"
SCHEME_NAME="${SDK_NAME}"

BUILD_DIR="${WORK_DIR}/build"
ARCHIVE_DIR="${BUILD_DIR}/Archives"
DERIVED_DATA_DIR="${BUILD_DIR}/DerivedData"

# Output dir
INSTALL_DIR="${WORK_DIR}/Products/${SDK_NAME}"

# Clear old build and output products
rm -rf "${BUILD_DIR}" "${INSTALL_DIR}"
mkdir -p "${ARCHIVE_DIR}" "${INSTALL_DIR}"

COMMON_BUILD_SETTINGS=(
  "SKIP_INSTALL=NO"
  "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
  "CODE_SIGNING_ALLOWED=NO"
)

DEVICE_ARCHIVE="${ARCHIVE_DIR}/${SDK_NAME}-iphoneos.xcarchive"
SIMULATOR_ARCHIVE="${ARCHIVE_DIR}/${SDK_NAME}-iphonesimulator.xcarchive"

# Build real device archive
xcodebuild archive \
  -project "${PROJECT_PATH}" \
  -configuration "${CONFIGURATION}" \
  -scheme "${SCHEME_NAME}" \
  -destination "generic/platform=iOS" \
  -archivePath "${DEVICE_ARCHIVE}" \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  "${COMMON_BUILD_SETTINGS[@]}"

# Build simulator archive
xcodebuild archive \
  -project "${PROJECT_PATH}" \
  -configuration "${CONFIGURATION}" \
  -scheme "${SCHEME_NAME}" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "${SIMULATOR_ARCHIVE}" \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  "${COMMON_BUILD_SETTINGS[@]}"

# Aggregate simulator and device archives
xcodebuild -create-xcframework \
  -framework "${DEVICE_ARCHIVE}/Products/Library/Frameworks/${SDK_NAME}.framework" \
  -framework "${SIMULATOR_ARCHIVE}/Products/Library/Frameworks/${SDK_NAME}.framework" \
  -output "${INSTALL_DIR}/${SDK_NAME}.xcframework"

# finally clear build
rm -rf "${BUILD_DIR}"