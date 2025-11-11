# iOS Code Signing Setup - Windows/WSL Guide

This guide shows how to create iOS certificates and provisioning profiles **without a Mac**, using OpenSSL on Windows (WSL or Git Bash).

## Prerequisites
- ✅ Apple Developer Account ($99/year)
- ✅ WSL (Ubuntu) or Git Bash installed on Windows
- ✅ OpenSSL (comes with WSL/Git Bash)

---

## Part 1: Create App ID (No Mac Required)

1. **Go to Apple Developer Portal:**
   - Visit: https://developer.apple.com/account/resources/identifiers/list
   - Sign in with your Apple Developer account

2. **Create App ID:**
   - Click the **+** button
   - Select **App IDs** → Continue
   - Select **App** → Continue
   - Fill in:
     - **Description**: Tarteel Student App
     - **Bundle ID**: `com.tarteel.student`
     - **Platform**: iOS
   - **Capabilities**: Check **Push Notifications**
   - Click **Continue** → **Register**

---

## Part 2: Create Certificate Using OpenSSL (Windows/WSL)

### Step 1: Generate Private Key and CSR

Open **WSL** or **Git Bash** and run:

```bash
# Navigate to a working directory
cd ~

# Create a directory for certificates
mkdir ios-certificates
cd ios-certificates

# Generate private key
openssl genrsa -out mykey.key 2048

# Generate Certificate Signing Request (CSR)
openssl req -new -key mykey.key -out CertificateSigningRequest.certSigningRequest -subj "/emailAddress=YOUR_EMAIL@example.com, CN=YOUR_NAME, C=US"
```

**Replace:**
- `YOUR_EMAIL@example.com` with your Apple ID email
- `YOUR_NAME` with your full name
- `US` with your country code (PK for Pakistan)

This creates two files:
- `mykey.key` - Your private key (KEEP THIS SAFE!)
- `CertificateSigningRequest.certSigningRequest` - CSR to upload

### Step 2: Upload CSR to Apple Developer Portal

1. **Go to Certificates:**
   - Visit: https://developer.apple.com/account/resources/certificates/list
   - Click the **+** button

2. **Select Certificate Type:**
   - Choose **Apple Distribution** (for App Store/TestFlight)
   - Click **Continue**

3. **Upload CSR:**
   - Click **Choose File**
   - Navigate to: `\\wsl$\Ubuntu\home\YOUR_USERNAME\ios-certificates\`
   - Select `CertificateSigningRequest.certSigningRequest`
   - Click **Continue**

4. **Download Certificate:**
   - Click **Download**
   - Save as `distribution.cer` in your Downloads folder

### Step 3: Convert Certificate to .p12 Format

Back in **WSL** or **Git Bash**:

```bash
# Navigate to certificates directory
cd ~/ios-certificates

# Copy the downloaded .cer file to WSL
# In Windows File Explorer, copy distribution.cer from Downloads
# In WSL, paste it to: /home/YOUR_USERNAME/ios-certificates/

# Or use this command:
cp /mnt/c/Users/skahm/Downloads/distribution.cer .

# Convert .cer to .pem format
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM

# Combine private key and certificate into .p12
openssl pkcs12 -export -out Certificates.p12 -inkey mykey.key -in distribution.pem

# You'll be asked to enter a password - REMEMBER THIS PASSWORD!
# Example: TarteelApp2025
```

**IMPORTANT:**
- Remember the password you set!
- You now have `Certificates.p12` file

---

## Part 3: Create Provisioning Profile (No Mac Required)

1. **Go to Profiles:**
   - Visit: https://developer.apple.com/account/resources/profiles/list
   - Click the **+** button

2. **Select Profile Type:**
   - Choose **App Store** (for TestFlight and App Store)
   - Click **Continue**

3. **Select App ID:**
   - Choose `com.tarteel.student`
   - Click **Continue**

4. **Select Certificate:**
   - Choose your **Apple Distribution** certificate
   - Click **Continue**

5. **Name Profile:**
   - **Name**: Tarteel Student Distribution
   - Click **Generate**

6. **Download Profile:**
   - Click **Download**
   - Save as `Tarteel_Student_Distribution.mobileprovision`

---

## Part 4: Convert to Base64 (WSL/Git Bash)

### Convert Certificate

```bash
cd ~/ios-certificates

# Convert .p12 to base64
base64 -w 0 Certificates.p12 > certificate_base64.txt

# View the base64 string (to copy)
cat certificate_base64.txt
```

**Copy the entire output** (Ctrl+Shift+C in WSL)

### Convert Provisioning Profile

```bash
# Copy provisioning profile to WSL
cp /mnt/c/Users/skahm/Downloads/Tarteel_Student_Distribution.mobileprovision .

# Convert to base64
base64 -w 0 Tarteel_Student_Distribution.mobileprovision > profile_base64.txt

# View the base64 string
cat profile_base64.txt
```

**Copy the entire output**

---

## Part 5: Add Secrets to GitHub

1. **Go to Your Repository:**
   - Visit: https://github.com/shahzaib93/tarteel-student-app

2. **Go to Secrets:**
   - Click **Settings** → **Secrets and variables** → **Actions**

3. **Add These 3 Secrets:**

   **Secret 1:**
   - Click **New repository secret**
   - **Name**: `IOS_CERTIFICATE_BASE64`
   - **Value**: Paste content from `certificate_base64.txt`
   - Click **Add secret**

   **Secret 2:**
   - Click **New repository secret**
   - **Name**: `IOS_CERTIFICATE_PASSWORD`
   - **Value**: The password you used when creating .p12 (e.g., TarteelApp2025)
   - Click **Add secret**

   **Secret 3:**
   - Click **New repository secret**
   - **Name**: `IOS_PROVISION_PROFILE_BASE64`
   - **Value**: Paste content from `profile_base64.txt`
   - Click **Add secret**

---

## Part 6: Update Bundle ID in Xcode Project

Since you don't have a Mac, you'll need to edit the Xcode project file directly:

### Option A: Edit project.pbxproj File

```bash
cd "/mnt/d/project/tarteel/video calling/mobile-apps/flutter-student-app"

# Open the Xcode project file
code ios/Runner.xcodeproj/project.pbxproj
```

Search for `PRODUCT_BUNDLE_IDENTIFIER` and make sure it's set to `com.tarteel.student`

### Option B: Let GitHub Actions Handle It

The bundle ID might already be correct. If the build fails due to bundle ID mismatch, we'll fix it then.

---

## Part 7: Trigger Signed Build

1. **Go to GitHub Actions:**
   - Visit: https://github.com/shahzaib93/tarteel-student-app/actions

2. **Run Workflow:**
   - Click **Build iOS App** workflow
   - Click **Run workflow** (green button)
   - Select `main` branch
   - Click **Run workflow**

3. **Monitor Build:**
   - Wait ~15-20 minutes
   - The `build-ios-signed` job will run

4. **Download IPA:**
   - Once complete, go to **Artifacts** section
   - Download `tarteel-student-ios.zip`
   - Extract to get `.ipa` file

---

## Part 8: Install IPA on iPhone (Without Mac)

### Option A: Using Diawi (Easiest)

1. **Upload IPA:**
   - Go to: https://www.diawi.com/
   - Drag your `.ipa` file
   - Wait for upload
   - Get a download link

2. **Install on iPhone:**
   - Open Safari on iPhone
   - Visit the Diawi link
   - Tap **Install**
   - Go to Settings → General → VPN & Device Management
   - Trust the developer certificate

### Option B: Using AltStore (Windows)

1. **Install AltServer:**
   - Download from: https://altstore.io/
   - Install on Windows

2. **Install AltStore on iPhone:**
   - Connect iPhone via USB
   - Follow AltStore setup instructions

3. **Install IPA:**
   - Open AltStore on iPhone
   - Tap **My Apps** → **+**
   - Select your `.ipa` file
   - Enter Apple ID password

### Option C: Using Sideloadly (Windows)

1. **Download Sideloadly:**
   - Visit: https://sideloadly.io/
   - Download for Windows

2. **Install IPA:**
   - Connect iPhone via USB
   - Open Sideloadly
   - Drag `.ipa` file
   - Enter Apple ID and password
   - Click **Start**

---

## Troubleshooting

### "base64: invalid input" Error
```bash
# Make sure you're in the right directory
cd ~/ios-certificates

# Check files exist
ls -la
```

### Can't Find .cer or .mobileprovision Files in WSL
```bash
# The path to Windows Downloads from WSL is:
ls /mnt/c/Users/skahm/Downloads/

# Copy files:
cp /mnt/c/Users/skahm/Downloads/distribution.cer ~/ios-certificates/
cp /mnt/c/Users/skahm/Downloads/Tarteel_Student_Distribution.mobileprovision ~/ios-certificates/
```

### Build Fails with "Code Signing Error"
- Double-check all 3 GitHub secrets are correct
- Make sure certificate password is correct
- Verify bundle ID is `com.tarteel.student`

### IPA Won't Install on iPhone
- Make sure you used **App Store** distribution profile (not Ad Hoc)
- Or add your iPhone's UDID to the provisioning profile

---

## Summary: Commands to Run

```bash
# 1. Generate certificate files
cd ~
mkdir ios-certificates
cd ios-certificates
openssl genrsa -out mykey.key 2048
openssl req -new -key mykey.key -out CertificateSigningRequest.certSigningRequest -subj "/emailAddress=YOUR_EMAIL@example.com, CN=YOUR_NAME, C=PK"

# 2. After downloading distribution.cer from Apple:
cp /mnt/c/Users/skahm/Downloads/distribution.cer .
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM
openssl pkcs12 -export -out Certificates.p12 -inkey mykey.key -in distribution.pem

# 3. After downloading provisioning profile:
cp /mnt/c/Users/skahm/Downloads/Tarteel_Student_Distribution.mobileprovision .

# 4. Convert to base64:
base64 -w 0 Certificates.p12 > certificate_base64.txt
base64 -w 0 Tarteel_Student_Distribution.mobileprovision > profile_base64.txt

# 5. View and copy base64 strings:
cat certificate_base64.txt
cat profile_base64.txt
```

Then add the base64 strings to GitHub Secrets!

---

## Next Steps

1. ✅ Run OpenSSL commands to create CSR
2. ✅ Upload CSR to Apple Developer Portal
3. ✅ Download certificate
4. ✅ Convert to .p12 with OpenSSL
5. ✅ Create provisioning profile
6. ✅ Convert both to base64
7. ✅ Add 3 secrets to GitHub
8. ✅ Trigger build
9. ✅ Download .ipa
10. ✅ Install on iPhone using Diawi/AltStore/Sideloadly

**Start with Part 2, Step 1 and let me know if you get stuck!**
