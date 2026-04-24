f#!/bin/bash
# Walkies - App Locker with Step Goals Build & Setup Script
# This script automates the initial setup process

set -e

echo "🚶 Walkies - App Locker Setup Script"
echo "===================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Check Flutter
echo -e "${BLUE}1. Checking Flutter installation...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${YELLOW}Flutter not found. Please install Flutter: https://flutter.dev/docs/get-started/install${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Flutter found: $(flutter --version | head -1)${NC}"
echo ""

# Step 2: Install dependencies
echo -e "${BLUE}2. Installing dependencies...${NC}"
flutter clean
flutter pub get
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

# Step 3: Run analysis
echo -e "${BLUE}3. Running code analysis...${NC}"
flutter analyze --no-preamble 2>&1 | tail -5 || true
echo -e "${GREEN}✓ Analysis complete${NC}"
echo ""

# Step 4: Display setup instructions
echo -e "${BLUE}4. Setup Instructions:${NC}"
echo ""
echo "Before running the app, you need to:"
echo ""
echo "  A) Create a Supabase project:"
echo "     1. Go to https://app.supabase.com"
echo "     2. Sign up and create a new project"
echo "     3. Note your Project URL and Anon Key"
echo ""
echo "  B) Setup the database:"
echo "     1. Open Supabase Project > SQL Editor"
echo "     2. Paste the contents of SUPABASE_SCHEMA.sql"
echo "     3. Execute the SQL"
echo ""
echo "  C) Configure the app:"
echo "     1. Edit lib/main.dart (lines 14-17)"
echo "     2. Replace YOUR_SUPABASE_URL with your Project URL"
echo "     3. Replace YOUR_SUPABASE_ANON_KEY with your Anon Key"
echo ""
echo "  D) Run the app:"
echo "     flutter run"
echo ""

echo -e "${GREEN}Setup script complete!${NC}"
echo "Happy Walking! 🚶‍♂️"
