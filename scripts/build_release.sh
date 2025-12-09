#!/bin/bash

# Exit on error
set -e

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    exit 1
fi

echo "🧹 Cleaning build..."
flutter clean

echo "🚀 Starting Release Build..."
echo "📖 Reading configuration from .env..."

# Use an array to store arguments
dart_defines=()

while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip comments and empty lines
    if [[ $key =~ ^#.* ]] || [ -z "$key" ]; then
        continue
    fi
    # Trim whitespace and remove carriage returns (fix for Windows line endings)
    key=$(echo "$key" | tr -d '\r' | xargs)
    value=$(echo "$value" | tr -d '\r' | xargs)
    
    if [ -n "$key" ] && [ -n "$value" ]; then
        dart_defines+=("--dart-define" "$key=$value")
    fi
done < .env

echo "🛠️  Building App Bundle with ${#dart_defines[@]} definitions..."
# echo "📋 Arguments: ${dart_defines[*]}" # Commented out to avoid leaking secrets in logs

# Run the build command
# Redirect output to a log file for easier debugging
flutter build appbundle --release "${dart_defines[@]}" > build_log.txt 2>&1

echo "✅ Build Complete!"
echo "📂 Output: build/app/outputs/bundle/release/app-release.aab"
