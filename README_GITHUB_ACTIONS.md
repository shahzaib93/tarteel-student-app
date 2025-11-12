# Tarteel Student App - GitHub Actions iOS Build Setup

This document explains how to build your iOS app using GitHub Actions.

## Quick Start

1. **Push to GitHub:**
   ```bash
   git init
   git add .
   git commit -m "Initial commit: Flutter student app"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
   git push -u origin main
   ```

2. **Trigger Build:**
   - Go to your GitHub repository
   - Click **Actions** tab
   - Click **Build iOS App** workflow
   - Click **Run workflow** button
   - Select `main` branch
   - Click **Run workflow**

3. **Download Build:**
   - Wait for the workflow to complete (~10-15 minutes)
   - Click on the completed workflow run
   - Scroll to **Artifacts** section
   - Download `ios-build` artifact

## Build Options

### Option 1: Unsigned Build (Default)
- Builds without code signing
- Creates `Runner.app` file
- Good for testing on simulator
- Runs automatically on every push to `main`

### Option 2: Signed Build (Manual)
- Requires iOS certificates and provisioning profile
- Creates `.ipa` file for real devices
- Must be triggered manually
- Can upload to TestFlight

## Setting Up Code Signing

To build signed `.ipa` files, you need to add these secrets to your GitHub repository:

### 1. Export Your Certificates

On a Mac with Xcode:

```bash
# Export certificate as .p12 file
# 1. Open Keychain Access
# 2. Find your iOS Distribution certificate
# 3. Right-click → Export
# 4. Save as .p12 with a password

# Convert to base64
base64 -i YourCertificate.p12 | pbcopy
```

### 2. Export Provisioning Profile

```bash
# Find your provisioning profile
cd ~/Library/MobileDevice/Provisioning\ Profiles
ls -la

# Convert to base64
base64 -i YOUR_PROFILE.mobileprovision | pbcopy
```

### 3. Add GitHub Secrets

Go to your GitHub repository:
- Settings → Secrets and variables → Actions → New repository secret

Add these secrets:
- `IOS_CERTIFICATE_BASE64`: Paste base64 certificate
- `IOS_CERTIFICATE_PASSWORD`: Your .p12 password
- `IOS_PROVISION_PROFILE_BASE64`: Paste base64 provisioning profile

### 4. (Optional) TestFlight Upload

For automatic TestFlight uploads, add:
- `APP_STORE_CONNECT_API_KEY`: Your App Store Connect API Key
- `APP_STORE_CONNECT_ISSUER_ID`: Your Issuer ID

Get these from: https://appstoreconnect.apple.com/access/api

## Workflow Files

- `.github/workflows/ios-build.yml` - Main build workflow
- Automatically runs on push to `main` branch
- Can be triggered manually via **Actions** tab

## Firebase Configuration

The app uses Firebase with these services:
- Firebase Authentication
- Cloud Firestore
- (Optional) Firebase Messaging

Configuration file: `lib/firebase_options.dart`

## WebRTC Signaling Server

Update the signaling server URL in:
- `lib/services/webrtc_service.dart:36`
- Change `http://localhost:3000` to your deployed server URL

## Troubleshooting

### Build Fails with "Pod install error"
- This is usually fine, GitHub Actions will retry
- CocoaPods dependencies are cached

### "Code signing error"
- Make sure all secrets are properly base64 encoded
- Check certificate and provisioning profile are valid
- Ensure bundle ID matches your provisioning profile

### "Flutter version mismatch"
- Edit `.github/workflows/ios-build.yml`
- Change `flutter-version: '3.24.5'` to your version

## Testing the App

### On Simulator (Mac required)
```bash
# Download the Runner.app artifact
# Unzip it
# Drag to Simulator or:
xcrun simctl install booted path/to/Runner.app
xcrun simctl launch booted com.tarteel.student
```

### On Real Device
1. Use the signed `.ipa` file
2. Install via Xcode, TestFlight, or third-party tools

## Support

For issues with:
- Flutter setup: https://docs.flutter.dev/
- GitHub Actions: https://docs.github.com/actions
- iOS signing: https://developer.apple.com/

## Next Steps

1. ✅ Push code to GitHub
2. ✅ Run workflow
3. ✅ Download build
4. ⏳ Set up code signing (for real devices)
5. ⏳ Configure TestFlight (optional)
