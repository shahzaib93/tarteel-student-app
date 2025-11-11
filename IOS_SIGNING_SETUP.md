# iOS Code Signing Setup Guide

This guide will help you create signed iOS builds that can be installed on your iPhone.

## Prerequisites
- ✅ Apple Developer Account ($99/year)
- ✅ Access to a Mac (for certificate creation)
- ✅ Xcode installed on Mac

---

## Part 1: Create App ID (Apple Developer Portal)

1. **Go to Apple Developer Portal:**
   - Visit: https://developer.apple.com/account/resources/identifiers/list
   - Sign in with your Apple Developer account

2. **Create App ID:**
   - Click the **+** button (or "Register an App ID")
   - Select **App IDs** → Continue
   - Select **App** → Continue
   - Fill in details:
     - **Description**: Tarteel Student App
     - **Bundle ID**: `com.tarteel.student` (must match your Flutter app)
     - **Platform**: iOS
   - **Capabilities**:
     - Check **Push Notifications** (for Firebase Messaging)
     - Check **Associated Domains** (if using deep links)
   - Click **Continue** → **Register**

---

## Part 2: Create iOS Distribution Certificate (On Mac)

### Step 1: Create Certificate Signing Request (CSR)

1. **Open Keychain Access on Mac:**
   - Applications → Utilities → Keychain Access

2. **Request Certificate:**
   - Keychain Access menu → Certificate Assistant → **Request a Certificate from a Certificate Authority**
   - Fill in:
     - **User Email**: Your Apple ID email
     - **Common Name**: Your name
     - **CA Email**: Leave empty
     - Select: **Saved to disk**
   - Click **Continue**
   - Save as `CertificateSigningRequest.certSigningRequest`

### Step 2: Create Distribution Certificate

1. **Go to Certificates Page:**
   - Visit: https://developer.apple.com/account/resources/certificates/list
   - Click the **+** button

2. **Select Certificate Type:**
   - Choose **Apple Distribution** (for App Store/TestFlight)
   - Click **Continue**

3. **Upload CSR:**
   - Click **Choose File**
   - Select the `.certSigningRequest` file you created
   - Click **Continue**

4. **Download Certificate:**
   - Click **Download**
   - Save as `distribution.cer`

5. **Install Certificate:**
   - Double-click `distribution.cer`
   - It will be added to Keychain Access

### Step 3: Export Certificate as .p12

1. **Open Keychain Access:**
   - Find your certificate (should be named "Apple Distribution: Your Name")
   - Expand the arrow next to it to see the private key

2. **Export:**
   - Right-click on the certificate (not the key)
   - Select **Export "Apple Distribution: ..."**
   - Save as `Certificates.p12`
   - **Set a password** (you'll need this later)
   - **IMPORTANT**: Remember this password!

---

## Part 3: Create Provisioning Profile

1. **Go to Profiles Page:**
   - Visit: https://developer.apple.com/account/resources/profiles/list
   - Click the **+** button

2. **Select Profile Type:**
   - Choose **App Store** (for TestFlight and App Store distribution)
   - Click **Continue**

3. **Select App ID:**
   - Choose `com.tarteel.student` (the App ID you created earlier)
   - Click **Continue**

4. **Select Certificate:**
   - Choose your **Apple Distribution** certificate
   - Click **Continue**

5. **Name Profile:**
   - **Provisioning Profile Name**: Tarteel Student Distribution
   - Click **Generate**

6. **Download Profile:**
   - Click **Download**
   - Save as `Tarteel_Student_Distribution.mobileprovision`

---

## Part 4: Convert to Base64 (On Mac)

Now you need to convert both files to base64 for GitHub Secrets.

### Convert Certificate (.p12)

```bash
# Open Terminal on Mac
cd ~/Downloads

# Convert certificate to base64 and copy to clipboard
base64 -i Certificates.p12 | pbcopy

# The base64 string is now in your clipboard
```

**Save this somewhere temporarily** (TextEdit, Notes, etc.)

### Convert Provisioning Profile

```bash
# Convert provisioning profile to base64 and copy to clipboard
base64 -i Tarteel_Student_Distribution.mobileprovision | pbcopy

# The base64 string is now in your clipboard
```

**Save this somewhere temporarily as well**

---

## Part 5: Add Secrets to GitHub

1. **Go to Your Repository:**
   - Visit: https://github.com/shahzaib93/tarteel-student-app

2. **Navigate to Secrets:**
   - Click **Settings** tab
   - Click **Secrets and variables** → **Actions**

3. **Add Certificate Secret:**
   - Click **New repository secret**
   - **Name**: `IOS_CERTIFICATE_BASE64`
   - **Value**: Paste the base64 certificate string (from Step 4)
   - Click **Add secret**

4. **Add Certificate Password Secret:**
   - Click **New repository secret**
   - **Name**: `IOS_CERTIFICATE_PASSWORD`
   - **Value**: The password you set when exporting the .p12 file
   - Click **Add secret**

5. **Add Provisioning Profile Secret:**
   - Click **New repository secret**
   - **Name**: `IOS_PROVISION_PROFILE_BASE64`
   - **Value**: Paste the base64 provisioning profile string
   - Click **Add secret**

---

## Part 6: Update Flutter App Bundle ID

Make sure your Flutter app uses the correct Bundle ID:

1. **Open file:** `ios/Runner.xcodeproj/project.pbxproj`
2. **Search for:** `PRODUCT_BUNDLE_IDENTIFIER`
3. **Verify it says:** `com.tarteel.student`

Or use Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Click on **Runner** project
3. Select **Runner** target
4. Under **General** tab → **Identity**
5. Set **Bundle Identifier** to: `com.tarteel.student`

---

## Part 7: Trigger Signed Build

1. **Go to GitHub Actions:**
   - Visit: https://github.com/shahzaib93/tarteel-student-app/actions

2. **Select Workflow:**
   - Click on **Build iOS App** workflow

3. **Run Workflow:**
   - Click **Run workflow** dropdown (green button)
   - Select `main` branch
   - Click **Run workflow**

4. **Wait for Build:**
   - The build takes ~15-20 minutes
   - You'll see two jobs:
     - `build-ios` (unsigned) - skips automatically
     - `build-ios-signed` (signed) - runs and creates .ipa

5. **Download IPA:**
   - Once complete, scroll to **Artifacts**
   - Download `tarteel-student-ios`
   - Unzip to get your `.ipa` file

---

## Part 8: Install IPA on iPhone

### Option A: Via Xcode (Mac Required)

1. **Connect iPhone to Mac**
2. **Open Xcode:**
   - Window → Devices and Simulators
3. **Select your iPhone**
4. **Drag .ipa file** to the "Installed Apps" section

### Option B: Via TestFlight (Recommended)

1. **Upload to App Store Connect:**
   - Use Xcode or Application Loader
   - Or set up automatic upload (see Part 9)

2. **Add to TestFlight:**
   - Go to App Store Connect
   - Select your app
   - Go to TestFlight tab
   - Add internal testers (your email)

3. **Install from iPhone:**
   - Install TestFlight app from App Store
   - Open invitation email
   - Tap **View in TestFlight**
   - Install app

### Option C: Via Third-Party Tools

Tools like **AltStore**, **Sideloadly**, or **Diawi** can install IPAs without Mac.

---

## Part 9: (Optional) Automatic TestFlight Upload

To automatically upload to TestFlight after building:

### Step 1: Create App Store Connect API Key

1. **Go to App Store Connect:**
   - Visit: https://appstoreconnect.apple.com/access/api
   - Click **Keys** tab (under Team Keys)

2. **Create Key:**
   - Click **+** button
   - **Name**: GitHub Actions
   - **Access**: Developer
   - Click **Generate**

3. **Download Key:**
   - Click **Download API Key** (can only download once!)
   - Save as `AuthKey_XXXXXXXXXX.p8`
   - **Note the Issuer ID** (displayed at top)
   - **Note the Key ID** (10-character string)

### Step 2: Convert API Key to Base64

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

### Step 3: Add Secrets to GitHub

Add these additional secrets:
- `APP_STORE_CONNECT_API_KEY`: Base64 encoded .p8 file
- `APP_STORE_CONNECT_ISSUER_ID`: Your Issuer ID
- `APP_STORE_CONNECT_KEY_ID`: Your 10-character Key ID

The workflow will now automatically upload to TestFlight!

---

## Troubleshooting

### Error: "No certificate found"
- Make sure you exported the certificate WITH the private key
- The certificate should expand to show a key in Keychain Access

### Error: "Profile doesn't match bundle ID"
- Check Bundle ID in Xcode matches `com.tarteel.student`
- Recreate provisioning profile if needed

### Error: "Certificate expired"
- Distribution certificates expire after 1 year
- Create a new certificate and update GitHub secrets

### Build succeeds but IPA won't install
- Make sure your iPhone UDID is added to the provisioning profile (for Ad Hoc distribution)
- Or use App Store distribution and upload to TestFlight

---

## Summary Checklist

- [ ] Create App ID: `com.tarteel.student`
- [ ] Create iOS Distribution Certificate
- [ ] Export certificate as .p12 with password
- [ ] Create Provisioning Profile
- [ ] Convert both to base64
- [ ] Add 3 secrets to GitHub:
  - `IOS_CERTIFICATE_BASE64`
  - `IOS_CERTIFICATE_PASSWORD`
  - `IOS_PROVISION_PROFILE_BASE64`
- [ ] Update Bundle ID in Xcode to `com.tarteel.student`
- [ ] Trigger signed build workflow
- [ ] Download .ipa from artifacts
- [ ] Install on iPhone via Xcode/TestFlight

---

## Need Help?

If you get stuck on any step, let me know which part and I'll help you through it!
