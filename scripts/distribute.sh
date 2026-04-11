#!/bin/bash

# Firebase App Distribution Script for i2i-v3
# Usage: ./scripts/distribute.sh [release-notes]
# Example: ./scripts/distribute.sh "v3.1 — Conversaciones independientes"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="${PROJECT_DIR}/ios"
BUILD_DIR="${PROJECT_DIR}/build"
SCHEME="i2i"
BUNDLE_ID="com.i2i.app"
RELEASE_NOTES="${1:-v3.1 — Conversaciones independientes}"

# Check prerequisites
echo -e "${YELLOW}[1/5] Verificando requisitos previos...${NC}"

if [ ! -d "$IOS_DIR" ]; then
    echo -e "${RED}Error: ios directory not found at $IOS_DIR${NC}"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild not found. Install Xcode Command Line Tools.${NC}"
    exit 1
fi

if ! command -v firebase &> /dev/null; then
    echo -e "${YELLOW}Firebase CLI not found. Installing...${NC}"
    npm install -g firebase-tools
fi

# Check for required environment variables
if [ -z "$FIREBASE_APP_ID" ]; then
    echo -e "${RED}Error: FIREBASE_APP_ID environment variable not set${NC}"
    echo -e "${YELLOW}Set it with: export FIREBASE_APP_ID='...'${NC}"
    exit 1
fi

# Create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Generate Xcode project with xcodegen
echo -e "${YELLOW}[2/5] Generando proyecto Xcode con xcodegen...${NC}"
cd "$IOS_DIR"

if ! command -v xcodegen &> /dev/null; then
    echo -e "${YELLOW}xcodegen not found. Installing...${NC}"
    brew install xcodegen
fi

xcodegen generate

# Step 2: Build archive
echo -e "${YELLOW}[3/5] Compilando archivo (.xcarchive)...${NC}"
xcodebuild archive \
    -scheme "$SCHEME" \
    -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
    -configuration Release \
    -allowProvisioningUpdates

# Step 3: Export as .ipa
echo -e "${YELLOW}[4/5] Exportando como .ipa (Ad-Hoc)...${NC}"
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
    -exportOptionsPlist "$PROJECT_DIR/scripts/ExportOptions.plist" \
    -exportPath "$BUILD_DIR/" \
    -allowProvisioningUpdates

# Verify .ipa was created
if [ ! -f "$BUILD_DIR/$SCHEME.ipa" ]; then
    echo -e "${RED}Error: .ipa file was not created at $BUILD_DIR/$SCHEME.ipa${NC}"
    exit 1
fi

# Step 4: Distribute via Firebase
echo -e "${YELLOW}[5/5] Distribuindo a Firebase App Distribution...${NC}"
firebase appdistribution:distribute "$BUILD_DIR/$SCHEME.ipa" \
    --app "$FIREBASE_APP_ID" \
    --groups "beta-testers" \
    --release-notes "$RELEASE_NOTES"

echo -e "${GREEN}✅ Distribución completada exitosamente!${NC}"
echo -e "${GREEN}Los testers recibirán un email con el link de instalación.${NC}"
