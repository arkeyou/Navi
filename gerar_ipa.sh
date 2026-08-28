#!/bin/bash

set -e

VERSION=$(xcodebuild \
  -project Navi.xcodeproj \
  -scheme Navi \
  -showBuildSettings |
  grep MARKETING_VERSION |
  head -1 |
  awk '{print $3}')

BUILD=$(xcodebuild \
  -project Navi.xcodeproj \
  -scheme Navi \
  -showBuildSettings |
  grep CURRENT_PROJECT_VERSION |
  head -1 |
  awk '{print $3}')

echo "Version: $VERSION"
echo "Build: $BUILD"

rm -rf build

xcodebuild \
  -project Navi.xcodeproj \
  -scheme Navi \
  -configuration Release \
  -archivePath build/Navi.xcarchive \
  archive

xcodebuild \
  -exportArchive \
  -archivePath build/Navi.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist gerar_ipa_exportOptions.plist

mkdir -p release

cp build/export/Navi.ipa \
   "release/Navi-${VERSION}.ipa"

SHA=$(shasum -a 256 "release/Navi-${VERSION}.ipa" | awk '{print $1}')

echo ""
echo "IPA:"
echo "release/Navi-${VERSION}.ipa"
echo ""
echo "SHA256:"
echo "$SHA"
