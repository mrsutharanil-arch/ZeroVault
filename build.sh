#!/bin/bash
# ZeroVault - One-Click Local Build Script for macOS & Xcode

set -e

PROJECT_NAME="ZeroVault.xcodeproj"
SCHEME="ZeroVault"
BUILD_DIR="./build"

echo "=========================================================="
echo "🛡️ Building ZeroVault: Sovereign Owner-Only Encrypted Vault"
echo "=========================================================="

if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: xcodebuild is not installed or not in PATH."
    echo "Please run this script on macOS with Xcode installed."
    exit 1
fi

echo "📋 Using Xcode version:"
xcodebuild -version
echo ""

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "🔨 Compiling ZeroVault for iOS Simulator..."
xcodebuild \
  -project "$PROJECT_NAME" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build

echo "✅ ZeroVault built successfully!"
