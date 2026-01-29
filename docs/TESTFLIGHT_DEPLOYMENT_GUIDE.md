# TestFlight Deployment Guide
## FishAndChips App

This guide walks through deploying the FishAndChips app to TestFlight for beta testing.

## Current Status

✅ **Completed:**
- CloudKit container created: `iCloud.com.nicolascooper.FishAndChips`
- Record types created in Development environment
- CloudKit sync service implemented
- Unit tests passing (43 tests, ~65-70% coverage)
- Push notifications configured

⚠️ **Ready for:**
- CloudKit Production deployment
- TestFlight build upload
- Beta testing with real devices

---

## Step 1: CloudKit Dashboard Setup

### 1.1 Add Query Indexes

Indexes are required for efficient CloudKit queries. Add these in the CloudKit Dashboard:

**Access:** [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard) → Select `iCloud.com.nicolascooper.FishAndChips` → Development → Schema → Indexes

#### User Record Type (3 indexes)

1. **username_queryable**
   - Type: QUERYABLE
   - Field: username
   - Sort: None

2. **username_sortable**
   - Type: SORTABLE
   - Field: username

3. **email_queryable**
   - Type: QUERYABLE
   - Field: email
   - Sort: None

#### Game Record Type (1 index)

1. **timestamp_queryable**
   - Type: QUERYABLE
   - Field: timestamp
   - Sort: None

#### PlayerProfile Record Type (1 index)

1. **displayName_queryable**
   - Type: QUERYABLE
   - Field: displayName
   - Sort: None

#### PlayerAlias Record Type (1 index)

1. **aliasName_queryable**
   - Type: QUERYABLE
   - Field: aliasName
   - Sort: None

#### PlayerClaim Record Type (3 indexes)

1. **playerName_queryable**
   - Type: QUERYABLE
   - Field: playerName
   - Sort: None

2. **status_queryable**
   - Type: QUERYABLE
   - Field: status
   - Sort: None

3. **createdAt_queryable**
   - Type: QUERYABLE
   - Field: createdAt
   - Sort: None

**Total: 9 indexes**

### 1.2 Deploy Schema to Production

⚠️ **IMPORTANT:** After deploying to Production, you CANNOT delete record types or fields. You can only add new ones.

**Steps:**
1. In CloudKit Dashboard, click **"Deploy Schema Changes"**
2. Select: **Development → Production**
3. Review changes carefully
4. Click **"Deploy"**
5. Wait 2-5 minutes for completion
6. Verify deployment: Check Production environment has all record types and indexes

---

## Step 2: App Store Connect Setup

### 2.1 Create App ID (Apple Developer Portal)

**Access:** [Apple Developer Portal](https://developer.apple.com/account) → Certificates, Identifiers & Profiles → Identifiers

1. Click **(+)** to create new identifier
2. Select **App IDs** → **App**
3. Fill in:
   - **Description:** FishAndChips
   - **Bundle ID:** `com.nicolascooper.FishAndChips` (Explicit)
   - **Capabilities:**
     - ✓ CloudKit
     - ✓ Push Notifications
     - ✓ iCloud
     - ✓ Background Modes
4. Click **Continue** → **Register**

### 2.2 Create App in App Store Connect

**Access:** [App Store Connect](https://appstoreconnect.apple.com) → My Apps

1. Click **(+)** → **New App**
2. Fill in:
   - **Platform:** iOS
   - **Name:** FishAndChips (or gamesCheck)
   - **Primary Language:** Russian (or English)
   - **Bundle ID:** Select `com.nicolascooper.FishAndChips`
   - **SKU:** FISHANDCHIPS-001 (unique identifier)
   - **User Access:** Full Access
3. Click **Create**

### 2.3 Prepare App Metadata

**Required Information:**

#### Basic Info
- **App Name:** FishAndChips (or gamesCheck)
- **Subtitle:** Tracking poker games and player stats (optional)
- **Category:** Games → Card (or Utilities)

#### Privacy Policy
You need a Privacy Policy URL. Create a simple one covering:
- What data is collected (game results, player names)
- How data is stored (iCloud/CloudKit)
- Data sharing policy (none)
- User rights (data deletion)

Host on GitHub Pages, personal website, or use a privacy policy generator.

#### App Description

```
gamesCheck - удобное приложение для отслеживания покерных игр и статистики игроков.

Основные возможности:
• Создание и управление играми
• Отслеживание buy-in и cashout для каждого игрока
• Детальная статистика по игрокам
• Автоматическая синхронизация через iCloud
• Система профилей и алиасов игроков
• Управление заявками на профили

Приложение использует CloudKit для безопасной синхронизации данных между вашими устройствами.
```

#### Screenshots

**Minimum requirement:** 1 device size (6.7" recommended)

**6.7" Display (iPhone 15 Pro Max):**
- Resolution: 1290 x 2796 pixels
- Portrait orientation
- Take screenshots in Simulator or on device

**Tips:**
- Show main features: game list, player statistics, add game screen
- Use real data examples
- Consider adding captions/annotations
- Minimum 1 screenshot, maximum 10 per device size

#### What's New (Version 1.0)

```
Первый релиз приложения!

• Отслеживание покерных игр
• Статистика игроков
• Синхронизация через iCloud
• Система профилей игроков
```

---

## Step 3: Xcode Configuration for Release

### 3.1 Verify Project Settings

Open `FishAndChips.xcodeproj` in Xcode:

#### General Tab
- **Display Name:** FishAndChips (or gamesCheck)
- **Bundle Identifier:** `com.nicolascooper.FishAndChips`
- **Version:** 1.0.0
- **Build:** 1
- **Deployment Target:** iOS 16.0 (or minimum supported version)

#### Signing & Capabilities
- **Automatically manage signing:** ✓ Enabled
- **Team:** Select your Apple Developer Team
- **Signing Certificate:** Apple Development (for development) / Apple Distribution (for release)

**Capabilities (verify all are present):**
- ✓ **CloudKit**
  - Container: `iCloud.com.nicolascooper.FishAndChips`
- ✓ **Push Notifications**
- ✓ **Background Modes**
  - Remote notifications
  - Background fetch
- ✓ **iCloud**
  - CloudKit

#### Build Settings
- **Scheme:** FishAndChips
- **Configuration for Archive:** Release (default)
- **Optimize for App Store:** Yes

### 3.2 Clean Up Temporary Code

The app currently has temporary CloudKit schema creation code that should be removed for production.

**File:** `FishAndChips/FishAndChipsApp.swift`

**Remove this section (lines 64-77):**

```swift
// TEMPORARY: Create CloudKit schema in Development mode
// ⚠️ Remove this code after schema is deployed to Production!
#if DEBUG
Task {
    do {
        print("🔧 Starting CloudKit schema creation...")
        try await CloudKitSchemaCreator().createDevelopmentSchema()
        print("✅ Schema creation completed! Check CloudKit Dashboard.")
    } catch {
        print("❌ Schema creation failed: \(error)")
        print("   Details: \(error.localizedDescription)")
    }
}
#endif
```

**Keep only the CloudKit status check:**

```swift
// Test CloudKit connection
Task {
    do {
        let status = try await CloudKitService.shared.checkAccountStatus()
        switch status {
        case .available:
            print("✅ CloudKit Status: AVAILABLE - Ready to use!")
        case .noAccount:
            print("❌ CloudKit Status: NO ACCOUNT - Please sign in to iCloud")
        case .restricted:
            print("⚠️ CloudKit Status: RESTRICTED - iCloud access is restricted")
        case .couldNotDetermine:
            print("⚠️ CloudKit Status: COULD NOT DETERMINE")
        case .temporarilyUnavailable:
            print("⚠️ CloudKit Status: TEMPORARILY UNAVAILABLE")
        @unknown default:
            print("⚠️ CloudKit Status: UNKNOWN")
        }
    } catch {
        print("❌ CloudKit Status Check Failed: \(error.localizedDescription)")
    }
}
```

---

## Step 4: Create Archive & Upload

### 4.1 Prepare for Archiving

1. **Select target device:**
   - Xcode toolbar: Select "Any iOS Device (arm64)"
   - Do NOT select a simulator

2. **Clean build folder:**
   - Xcode menu: `Product → Clean Build Folder` (⌘⇧K)

3. **Verify scheme:**
   - `Product → Scheme → Edit Scheme...`
   - Archive tab → Build Configuration: Release

### 4.2 Create Archive

1. **Archive the app:**
   - `Product → Archive` (⌘⇧B)
   - Or: `Product → Build` first to check for errors
   
2. **Wait for completion:**
   - This takes 3-5 minutes
   - Watch for build errors in the Report Navigator
   
3. **Organizer opens automatically**
   - Shows all your archives
   - Select the most recent archive

### 4.3 Validate Archive (Optional but Recommended)

Before uploading:

1. In Organizer, click **"Validate App"**
2. Select **App Store Connect**
3. Choose automatic signing
4. Click **Validate**
5. Wait for validation (~2-3 minutes)
6. Fix any issues found

### 4.4 Upload to App Store Connect

1. In Organizer, click **"Distribute App"**
2. Select **App Store Connect** → **Upload**
3. Configure options:
   - ✓ **Upload your app's symbols** (for crash reports)
   - ✓ **Manage Version and Build Number** (auto-increment)
4. Select **Automatically manage signing**
5. Review app info → **Upload**
6. Wait for upload completion (~5-10 minutes)
7. Receive confirmation email from Apple

---

## Step 5: TestFlight Setup

### 5.1 Build Processing

**After upload:**

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app → **TestFlight** tab
3. Build appears in **"Processing"** status
4. Wait **15-30 minutes** for processing
5. You'll receive email when processing completes

**If processing takes longer:**
- Check for email from Apple about issues
- Common issues: missing Info.plist keys, invalid entitlements
- Fix issues and upload new build

### 5.2 Export Compliance

After processing completes:

1. Click on the build number
2. **"Provide Export Compliance Information"**
3. Answer questions:
   - **"Is your app designed to use cryptography or does it contain or incorporate cryptography?"**
     - If only HTTPS: **No**
     - If using encryption: **Yes** → Select appropriate options
4. **For FishAndChips:** Select **No** (only uses standard HTTPS)
5. Click **Start Internal Testing**

### 5.3 Internal Testing

**Automatically included:**
- All users with Admin or App Manager role
- Up to 100 internal testers

**Add testers:**

1. TestFlight → **Internal Testing** section
2. Click **(+) Add Internal Testers**
3. Enter email addresses
4. Testers receive invite email immediately
5. They can install via TestFlight app

**What to test:**
- Basic app functionality
- CloudKit sync between devices
- Push notifications
- Offline mode
- Crash testing

### 5.4 External Testing (Optional)

For wider beta testing (up to 10,000 users):

1. TestFlight → **External Testing**
2. Click **Create Group**
3. Name: "Beta Testers"
4. Add build to test
5. Add testers (email addresses)
6. Fill in **"What to Test"** section

**Example "What to Test":**

```
Welcome to FishAndChips beta!

Please test:
1. Create a few poker games with different players
2. Add buy-ins and cashouts
3. Check player statistics
4. Test synchronization:
   - Install on 2 devices
   - Create game on device A
   - Check if it appears on device B within 1-2 minutes
5. Try offline mode (airplane mode)
6. Report any crashes or weird behavior

Thank you for testing!
```

7. **Submit for Beta App Review** (~24-48 hours)

---

## Step 6: CloudKit Synchronization Testing

### 6.1 Test Plan

**Requirements:**
- 2 iOS devices (or 1 device + 1 simulator)
- Both signed in to **different** iCloud accounts
- Both have TestFlight build installed

#### Test 1: Basic Sync - Create Game

**Device A:**
1. Open app
2. Create new game with 2-3 players
3. Add buy-ins and cashouts
4. Save game

**Device B:**
1. Wait 30-60 seconds
2. Pull to refresh (if implemented) or reopen app
3. **✓ Verify:** Game appears with correct data

#### Test 2: Edit Game

**Device A:**
1. Select existing game
2. Modify player amounts
3. Save changes

**Device B:**
1. Wait 30-60 seconds
2. Refresh
3. **✓ Verify:** Changes synchronized

#### Test 3: Delete Game

**Device A:**
1. Delete a game

**Device B:**
1. Wait 30-60 seconds
2. Refresh
3. **✓ Verify:** Game is removed/hidden

#### Test 4: Offline Mode

**Device A:**
1. Enable Airplane Mode
2. Create 2-3 new games
3. **✓ Verify:** Games saved locally
4. Disable Airplane Mode
5. Wait 1-2 minutes

**Device B:**
1. Refresh
2. **✓ Verify:** New games appeared

#### Test 5: Conflict Resolution

**Both devices:**
1. Enable Airplane Mode on both

**Device A:**
1. Edit Game #1 (change player A's cashout)

**Device B:**
1. Edit Same Game #1 (change player B's cashout)

**Both devices:**
1. Disable Airplane Mode
2. Wait 2-3 minutes
3. **✓ Verify:** Conflict resolved (latest change wins or merged)

### 6.2 Push Notification Testing

**Test PlayerClaim notifications:**

**Device A:**
1. Create new PlayerClaim
2. Assign to another user (if implemented)

**Device B:**
1. **✓ Verify:** Receive push notification
2. Tap notification
3. **✓ Verify:** App opens to correct screen

### 6.3 Success Criteria

✅ **Sync Requirements:**
- Synchronization works bidirectionally
- Sync delay < 2 minutes (typical: 30-60 seconds)
- No data loss
- Conflicts resolved gracefully
- Offline changes sync when back online

✅ **Stability Requirements:**
- No crashes during normal use
- No data corruption
- Crash rate < 0.1%
- App responsive (no freezing)

✅ **Notification Requirements:**
- Push notifications delivered
- Notifications open correct screen
- Background sync triggered by notifications

---

## Step 7: Bug Fixes & Iterations

### 7.1 Collecting Feedback

**TestFlight Feedback:**
- Testers can shake device to send feedback
- Access feedback in App Store Connect → TestFlight → Build → Feedback

**Crash Reports:**
- Xcode → Window → Organizer → Crashes
- Automatically collected with symbols uploaded

**Create bug tracking list:**
1. Document all reported issues
2. Include steps to reproduce
3. Assign priority

### 7.2 Priority Levels

**Critical (Must fix before release):**
- Data loss
- App crashes on launch
- Cannot sync data
- Cannot create/edit games

**High (Should fix):**
- UI bugs
- Slow performance
- Notification issues
- Partial data loss

**Medium (Nice to have):**
- Cosmetic issues
- Minor UX improvements
- Edge cases

**Low (Future versions):**
- Feature requests
- Non-critical enhancements

### 7.3 Release New Build

When bugs fixed:

1. **Increment build number:**
   - Xcode: General tab → Build: 1 → 2
   - Or use `agvtool next-version -all`

2. **Create new archive** (Step 4.2)
3. **Upload to TestFlight** (Step 4.4)
4. **Wait for processing** (~15-30 min)
5. **Notify testers** (optional):
   - App Store Connect → TestFlight → Select Build
   - Click "Notify Testers"
   - Add release notes

**Example release notes:**

```
Build 2 - Bug Fixes

Fixed:
• Crash when adding player without name
• Sync delay improved (now <60 seconds)
• Fixed offline mode data loss issue
• Improved error messages

Please retest sync functionality!
```

---

## Step 8: Production Release Preparation

### 8.1 Final Checklist

Before submitting for App Review:

- [ ] All critical bugs fixed
- [ ] Positive feedback from beta testers (>80%)
- [ ] Crash rate < 0.1% (check in App Store Connect → Analytics)
- [ ] CloudKit sync stable and reliable
- [ ] Push notifications working
- [ ] Privacy Policy live online
- [ ] All screenshots prepared
- [ ] App description finalized
- [ ] Keywords selected (for search optimization)
- [ ] Support URL set (can be GitHub repo or email)

### 8.2 App Review Information

Prepare test account for Apple reviewers:

1. Create test iCloud account
2. Pre-populate with sample data (2-3 games)
3. Provide credentials to Apple:
   - App Store Connect → Your App → 1.0 → App Review Information
   - **Sign-in required:** Yes
   - **Username:** test@example.com
   - **Password:** [test password]
   - **Notes:** Instructions for reviewers

**Example notes:**

```
App requires iCloud account for data synchronization.

Test account provided. Sample data is already populated.

To test main features:
1. View existing games on main screen
2. Tap "+" to add new game
3. Add players and amounts
4. Tap "Save"
5. View player statistics in "Players" tab

Synchronization happens automatically when using multiple devices.
```

### 8.3 Submit for Review

1. **App Store Connect** → Your App → **1.0 Prepare for Submission**
2. Fill all required fields:
   - Screenshots (all device sizes)
   - Description
   - Keywords
   - Support URL
   - Marketing URL (optional)
   - Privacy Policy URL
3. **Pricing and Availability:**
   - Price: Free (or set price)
   - Countries: Select markets
4. **App Review Information:**
   - Contact info
   - Demo account
   - Notes for reviewers
5. **Version Release:**
   - **Recommended for v1.0:** Manual release
   - This lets you control when app goes live after approval
6. Click **Submit for Review**

### 8.4 Review Timeline

**Typical timeline:**
- Standard review: 24-48 hours
- Complex apps: 3-5 days
- If rejected: Fix issues and resubmit (restart review queue)

**Possible rejection reasons:**
- Crashes during review
- Missing features described in screenshots
- Privacy Policy issues
- Guideline violations
- Incomplete app information

**If approved:**
1. Receive email notification
2. If "Manual release" selected:
   - Go to App Store Connect
   - Click "Release this Version"
3. App live on App Store within 24 hours

---

## Troubleshooting

### Build Upload Fails

**Error: "Invalid Entitlements"**
- Verify entitlements file matches capabilities in Xcode
- Check CloudKit container identifier is correct
- Ensure Push Notifications enabled

**Error: "Missing Info.plist keys"**
- Check NSCameraUsageDescription (if using camera)
- Verify NSFaceIDUsageDescription (if using biometrics)
- Add any missing privacy keys

**Error: "Invalid Bundle Identifier"**
- Ensure bundle ID matches App Store Connect
- Check for typos
- Verify App ID created in Developer Portal

### CloudKit Sync Not Working

**Check CloudKit status:**
```swift
let status = try await CloudKitService.shared.checkAccountStatus()
print("CloudKit status: \(status)")
```

**Common issues:**
- User not signed in to iCloud → Show alert
- CloudKit container ID mismatch → Check entitlements
- Schema not deployed to Production → Deploy in CloudKit Dashboard
- Network issues → Test on different network

### TestFlight Not Showing Build

**Possible reasons:**
- Build still processing (wait longer)
- Export compliance not completed
- Build rejected by Apple (check email)
- Team member doesn't have TestFlight role

**Solution:**
1. Check App Store Connect for status
2. Complete export compliance
3. Wait for processing email
4. Add user to internal testers

---

## Resources

### Essential Links

- [Apple Developer Portal](https://developer.apple.com/account)
- [App Store Connect](https://appstoreconnect.apple.com)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [TestFlight](https://testflight.apple.com)

### Documentation

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)

### Support

- [Apple Developer Forums](https://developer.apple.com/forums/)
- [Contact App Review](https://developer.apple.com/contact/app-store/)

---

## Success!

Once your app is live on the App Store:

1. **Monitor Analytics:**
   - App Store Connect → Analytics
   - Track downloads, crashes, ratings

2. **Respond to Reviews:**
   - Users appreciate developer responses
   - Address issues in next update

3. **Plan Updates:**
   - Fix reported bugs
   - Add requested features
   - Keep app updated for new iOS versions

4. **Marketing:**
   - Share on social media
   - Get feedback from users
   - Consider app store optimization (ASO)

Congratulations on shipping your app! 🎉
