# TestFlight Deployment Checklist
## Quick Reference Guide

This is a quick checklist for TestFlight deployment. Use this alongside the detailed guides.

---

## ✅ Automated Tasks (COMPLETED)

- [x] Remove temporary CloudKit schema creation code
- [x] Verify and update entitlements file
- [x] Verify Xcode project configuration
- [x] Create comprehensive deployment guide
- [x] Create App Store metadata templates
- [x] Create Privacy Policy HTML file

---

## 📋 Manual Tasks (YOUR ACTION REQUIRED)

### Phase 1: CloudKit Setup (15 minutes)
**Location:** [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)

- [ ] **1.1** Add 9 CloudKit indexes:
  - [ ] User: username_queryable, username_sortable, email_queryable
  - [ ] Game: timestamp_queryable  
  - [ ] PlayerProfile: displayName_queryable
  - [ ] PlayerAlias: aliasName_queryable
  - [ ] PlayerClaim: playerName_queryable, status_queryable, createdAt_queryable
  
- [ ] **1.2** Deploy schema to Production
  - ⚠️ WARNING: Cannot undo after deployment!
  - Navigate to: Development → Production
  - Click "Deploy Schema Changes"

**Reference:** `docs/TESTFLIGHT_DEPLOYMENT_GUIDE.md` Section 1

---

### Phase 2: Apple Developer Setup (10 minutes)
**Location:** [Apple Developer Portal](https://developer.apple.com/account)

- [ ] **2.1** Create App ID
  - Bundle ID: `com.nicolascooper.FishAndChips`
  - Capabilities: CloudKit, Push, iCloud, Background Modes
  
**Reference:** `docs/TESTFLIGHT_DEPLOYMENT_GUIDE.md` Section 2.1

---

### Phase 3: App Store Connect Setup (45 minutes)
**Location:** [App Store Connect](https://appstoreconnect.apple.com)

- [ ] **3.1** Host Privacy Policy
  - Upload `docs/privacy-policy.html` to GitHub Pages or your website
  - Note the URL: ______________________________________
  
- [ ] **3.2** Take screenshots (minimum 1 set)
  - Device: iPhone with 6.7" display (1290 x 2796 px)
  - Screens: Main list, Game details, Statistics, Add game
  
- [ ] **3.3** Create new app in App Store Connect
  - Name: FishAndChips (or gamesCheck)
  - Bundle ID: `com.nicolascooper.FishAndChips`
  - SKU: FISHANDCHIPS-001
  
- [ ] **3.4** Fill in metadata (use `docs/APP_STORE_METADATA.md`)
  - [ ] App name and subtitle
  - [ ] Description
  - [ ] Keywords
  - [ ] Category: Games → Card
  - [ ] Age rating: 12+
  - [ ] Privacy Policy URL
  - [ ] Screenshots
  
- [ ] **3.5** Create test account
  - Create new iCloud account for testing
  - Username: ______________________________________
  - Password: (store securely)
  - Add to App Review Information

**Reference:** `docs/TESTFLIGHT_DEPLOYMENT_GUIDE.md` Section 2  
**Metadata:** `docs/APP_STORE_METADATA.md`

---

### Phase 4: Build and Upload (30 minutes)
**Location:** Xcode

- [ ] **4.1** Prepare for archive
  - [ ] Open `FishAndChips.xcodeproj`
  - [ ] Select device: "Any iOS Device (arm64)"
  - [ ] Clean build folder (⌘⇧K)
  
- [ ] **4.2** Verify settings
  - [ ] Bundle ID: `com.nicolascooper.FishAndChips`
  - [ ] Version: 1.0
  - [ ] Build: 1
  - [ ] Team selected
  - [ ] Automatic signing enabled
  
- [ ] **4.3** Create archive
  - [ ] Product → Archive (⌘⇧B)
  - [ ] Wait for build (~5 minutes)
  - [ ] Organizer opens with archive
  
- [ ] **4.4** Validate (optional but recommended)
  - [ ] Click "Validate App"
  - [ ] Fix any errors
  
- [ ] **4.5** Upload to App Store Connect
  - [ ] Click "Distribute App"
  - [ ] Select: App Store Connect → Upload
  - [ ] Enable: Upload symbols, Manage version
  - [ ] Click Upload
  - [ ] Wait for completion (~10 minutes)
  - [ ] Check email for confirmation

**Reference:** `docs/TESTFLIGHT_DEPLOYMENT_GUIDE.md` Section 4

---

### Phase 5: TestFlight Configuration (20 minutes + processing time)
**Location:** App Store Connect → TestFlight

- [ ] **5.1** Wait for build processing
  - Status: "Processing" → "Ready"
  - Time: ~15-30 minutes
  - Check email for completion notification
  
- [ ] **5.2** Provide export compliance
  - [ ] Click on build
  - [ ] Answer encryption question (select "No" if only HTTPS)
  - [ ] Save
  
- [ ] **5.3** Start internal testing
  - [ ] Click "Start Internal Testing"
  - [ ] Add internal testers (email addresses)
  - [ ] Send invitations
  
- [ ] **5.4** (Optional) External testing
  - [ ] Create external test group
  - [ ] Add external testers
  - [ ] Submit for Beta App Review

**Reference:** `docs/TESTFLIGHT_DEPLOYMENT_GUIDE.md` Section 5

---

### Phase 6: CloudKit Sync Testing (1-2 hours)
**Requirements:** 2 devices with TestFlight build + different iCloud accounts

#### Test Scenarios

- [ ] **Test 1: Create Game**
  - [ ] Device A: Create game with players
  - [ ] Device B: Wait 60 seconds, verify game appears
  - Result: ✅ Pass / ❌ Fail
  
- [ ] **Test 2: Edit Game**
  - [ ] Device A: Modify existing game
  - [ ] Device B: Wait 60 seconds, verify changes
  - Result: ✅ Pass / ❌ Fail
  
- [ ] **Test 3: Delete Game**
  - [ ] Device A: Delete a game
  - [ ] Device B: Wait 60 seconds, verify deletion
  - Result: ✅ Pass / ❌ Fail
  
- [ ] **Test 4: Offline Mode**
  - [ ] Device A: Airplane mode ON, create 2 games
  - [ ] Device A: Airplane mode OFF, wait 2 minutes
  - [ ] Device B: Verify games appear
  - Result: ✅ Pass / ❌ Fail
  
- [ ] **Test 5: Conflict Resolution**
  - [ ] Both devices: Airplane mode ON
  - [ ] Device A: Edit game #1
  - [ ] Device B: Edit same game #1
  - [ ] Both: Airplane mode OFF, wait 2 minutes
  - [ ] Verify conflict resolved (no data loss)
  - Result: ✅ Pass / ❌ Fail
  
- [ ] **Test 6: Push Notifications**
  - [ ] Device A: Create PlayerClaim
  - [ ] Device B: Verify notification received
  - [ ] Tap notification, verify correct screen opens
  - Result: ✅ Pass / ❌ Fail

#### Success Criteria
- [ ] All 6 tests pass
- [ ] Sync delay < 2 minutes (typically 30-60 seconds)
- [ ] No crashes
- [ ] No data loss
- [ ] Conflict resolution works

**Reference:** `docs/TESTFLIGHT_DEPLOYMENT_GUIDE.md` Section 6

---

### Phase 7: Bug Fixes (if needed)

If any tests fail or bugs are found:

- [ ] **7.1** Document all issues
  - [ ] List each bug with steps to reproduce
  - [ ] Assign priority (Critical / High / Medium / Low)
  
- [ ] **7.2** Fix critical bugs
  - [ ] Make code changes
  - [ ] Test locally
  
- [ ] **7.3** Upload new build
  - [ ] Increment build number (1 → 2)
  - [ ] Create new archive
  - [ ] Upload to TestFlight
  - [ ] Notify testers
  - [ ] Re-run tests

**Reference:** `docs/TESTFLIGHT_DEPLOYMENT_GUIDE.md` Section 7

---

### Phase 8: Production Release (when ready)

- [ ] **8.1** Final checks
  - [ ] All critical bugs fixed
  - [ ] Positive tester feedback (>80%)
  - [ ] Crash rate < 0.1%
  - [ ] CloudKit sync stable
  - [ ] All metadata complete
  
- [ ] **8.2** Submit for App Review
  - [ ] App Store Connect → Version 1.0
  - [ ] Fill all required fields
  - [ ] Add demo account info
  - [ ] Version Release: Manual (recommended)
  - [ ] Click "Submit for Review"
  
- [ ] **8.3** Wait for approval
  - [ ] Typical time: 24-48 hours
  - [ ] Check status in App Store Connect
  - [ ] Respond to any feedback from Apple
  
- [ ] **8.4** Release app
  - [ ] Receive approval email
  - [ ] Click "Release this Version" (if manual release)
  - [ ] App live within 24 hours

**Reference:** `docs/TESTFLIGHT_DEPLOYMENT_GUIDE.md` Section 8

---

## 🎯 Quick Start

**If you're ready to start NOW, do this:**

1. **CloudKit Dashboard** (15 min)
   - Add indexes → Deploy to Production
   
2. **Break** ☕

3. **Apple Developer Portal** (5 min)
   - Create App ID
   
4. **Host Privacy Policy** (10 min)
   - Upload to GitHub Pages
   
5. **Break** ☕

6. **Take Screenshots** (20 min)
   - Open app on simulator/device
   - Capture 4-5 screens
   
7. **App Store Connect** (30 min)
   - Create app
   - Fill metadata
   - Upload screenshots
   
8. **Break** ☕

9. **Xcode** (30 min)
   - Create archive
   - Upload to TestFlight
   
10. **Wait** ⏳ (30 min)
    - Build processes
    - Check email
    
11. **TestFlight** (10 min)
    - Export compliance
    - Start testing
    
12. **Test** 🧪 (1-2 hours)
    - Run all 6 test scenarios
    
13. **Done!** 🎉

**Total active time:** ~3-4 hours  
**Total elapsed time:** ~5-6 hours (including waiting)

---

## 📞 Need Help?

### Documentation
- **Full guide:** `docs/TESTFLIGHT_DEPLOYMENT_GUIDE.md`
- **Metadata:** `docs/APP_STORE_METADATA.md`
- **Summary:** `docs/TESTFLIGHT_READINESS_SUMMARY.md`

### Apple Resources
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [Apple Developer Portal](https://developer.apple.com/account)
- [App Store Connect](https://appstoreconnect.apple.com)
- [TestFlight](https://testflight.apple.com)
- [Developer Support](https://developer.apple.com/contact/)

### Common Issues
See "Troubleshooting" section in `TESTFLIGHT_DEPLOYMENT_GUIDE.md`

---

## ✅ Completion Tracking

**Date Started:** ___________________

**Phase 1 (CloudKit):** ___________________  
**Phase 2 (App ID):** ___________________  
**Phase 3 (ASC Setup):** ___________________  
**Phase 4 (Build):** ___________________  
**Phase 5 (TestFlight):** ___________________  
**Phase 6 (Testing):** ___________________  
**Phase 7 (Fixes):** ___________________ (if needed)  
**Phase 8 (Submission):** ___________________

**TestFlight Ready:** ___________________  
**Submitted for Review:** ___________________  
**Approved:** ___________________  
**Live on App Store:** ___________________

---

**Good luck! You've got everything you need to deploy successfully.** 🚀

*Print this checklist and check off items as you go!*
