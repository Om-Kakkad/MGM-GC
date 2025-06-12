#!/bin/bash

echo "🧹 Cleaning up iOS build environment..."

# Close any running simulator
echo "📱 Closing iOS Simulator..."
killall "Simulator" &>/dev/null || true

# Clean Flutter build
echo "🧼 Cleaning Flutter build..."
flutter clean

# Clean Xcode's DerivedData
echo "🗑️ Removing Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset iOS Simulator
echo "🔄 Resetting iOS Simulator..."
xcrun simctl shutdown all 2>/dev/null
xcrun simctl erase all

# Fix permissions for Flutter ephemeral directory
echo "🔐 Fixing permissions for Flutter ephemeral directory..."
sudo chown -R $(whoami) ios/Flutter/ephemeral/ 2>/dev/null || true
chmod -R 755 ios/Flutter/ephemeral/ 2>/dev/null || true

# Clean Pod cache and reinstall
echo "📦 Cleaning CocoaPods cache..."
cd ios
rm -rf Pods
rm -f Podfile.lock
pod cache clean --all
pod install --repo-update
cd ..

echo "✅ Cleanup complete! Try running your tests again with:"
echo "flutter test integration_test/full_flow_test.dart"
