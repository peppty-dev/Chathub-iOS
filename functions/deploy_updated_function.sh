#!/bin/bash

# Firebase Cloud Function Modernization Deployment Script
# This script will update your Node.js runtime and dependencies, then deploy the modernized function

echo "🚀 Starting Firebase Cloud Function modernization deployment..."

# Navigate to the functions directory
cd "$(dirname "$0")/iosFunction"

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Make sure you're in the functions directory."
    exit 1
fi

echo "📦 Installing updated dependencies..."
# Install updated dependencies
npm install

echo "🧪 Testing function locally (optional)..."
# Uncomment the next line if you want to test locally first
# firebase emulators:start --only functions

echo "🌍 Deploying to Firebase..."
# Deploy only the iOS notification function
firebase deploy --only functions:NotificationsiOS

if [ $? -eq 0 ]; then
    echo "✅ Deployment successful!"
    echo ""
    echo "🎯 What was updated:"
    echo "   • Node.js runtime upgraded from 18 to 20"
    echo "   • Firebase Admin SDK updated to v12.7.0"
    echo "   • Firebase Functions updated to v6.1.0"
    echo "   • Modern FCM send() API instead of legacy sendToDevice()"
    echo "   • Async/await error handling"
    echo "   • Performance optimizations (256MB memory, 120s timeout)"
    echo "   • Enhanced APNS configuration for iOS"
    echo ""
    echo "📱 Your iOS notifications should now work more reliably!"
    echo "🔍 Monitor the function logs in Firebase Console to see the improvements."
else
    echo "❌ Deployment failed! Check the error messages above."
    exit 1
fi
