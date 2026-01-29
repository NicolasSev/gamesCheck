# CloudKit Setup Instructions

## ⚠️ Important: Manual Steps Required

The code for CloudKit integration has been created, but you need to complete the following manual steps in Xcode to enable CloudKit functionality.

---

## Step 1: Add CloudKit Capability in Xcode

1. Open `PokerCardRecognizer.xcodeproj` in Xcode
2. Select the `PokerCardRecognizer` target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search for and add **"CloudKit"**
6. In the CloudKit section, verify/add the container:
   - Container: `iCloud.com.nicolascooper.FishAndChips`

## Step 2: Add Push Notifications Capability (for Phase 4)

1. In the same **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add **"Push Notifications"**

## Step 3: Configure Background Modes

1. Click **+ Capability**
2. Add **"Background Modes"**
3. Check the following modes:
   - ☑️ Remote notifications
   - ☑️ Background fetch

## Step 4: Verify Entitlements File

The entitlements file has been created at:
`FishAndChips/FishAndChips.entitlements`

Verify it's linked to your target:
1. Select the target in Xcode
2. Go to **Build Settings**
3. Search for "Code Signing Entitlements"
4. Verify it points to: `FishAndChips/FishAndChips.entitlements`

## Step 5: Create CloudKit Container in Apple Developer Portal

1. Go to [developer.apple.com](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Identifiers**
4. Find your App ID: `com.nicolascooper.FishAndChips`
5. Click **Edit**
6. Enable **CloudKit** capability
7. Click **Configure** next to CloudKit
8. Add CloudKit Container:
   - Identifier: `iCloud.com.nicolascooper.FishAndChips`
   - Description: "FishAndChips CloudKit Container"
9. Save and register the container

## Step 6: Configure CloudKit Database Schema

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
2. Select your container: `iCloud.com.nicolascooper.FishAndChips`
3. Go to **Schema** → **Record Types**
4. Create the following Record Types:

### User Record Type
- Field: `username` (String, Indexed, Queryable)
- Field: `email` (String, Indexed, Queryable)
- Field: `passwordHash` (String)
- Field: `subscriptionStatus` (String)
- Field: `isSuperAdmin` (Int64)
- Field: `createdAt` (Date/Time)
- Field: `lastLoginAt` (Date/Time)
- Field: `subscriptionExpiresAt` (Date/Time)

### Game Record Type
- Field: `gameType` (String)
- Field: `timestamp` (Date/Time, Indexed)
- Field: `isPublic` (Int64)
- Field: `softDeleted` (Int64)
- Field: `notes` (String)
- Field: `creator` (Reference to User)

### PlayerProfile Record Type
- Field: `displayName` (String, Indexed, Queryable)
- Field: `isAnonymous` (Int64)
- Field: `createdAt` (Date/Time)
- Field: `totalGamesPlayed` (Int64)
- Field: `totalBuyins` (Double)
- Field: `totalCashouts` (Double)
- Field: `user` (Reference to User)

### PlayerAlias Record Type
- Field: `aliasName` (String, Indexed, Queryable)
- Field: `claimedAt` (Date/Time)
- Field: `gamesCount` (Int64)
- Field: `profile` (Reference to PlayerProfile)

### PlayerClaim Record Type
- Field: `playerName` (String, Indexed)
- Field: `gameWithPlayerObjectId` (String)
- Field: `status` (String, Indexed, Queryable)
- Field: `createdAt` (Date/Time, Indexed)
- Field: `resolvedAt` (Date/Time)
- Field: `notes` (String)
- Field: `game` (Reference to Game)
- Field: `claimantUser` (Reference to User)
- Field: `hostUser` (Reference to User)
- Field: `resolvedByUser` (Reference to User)

## Step 7: Test CloudKit Connection

1. Build and run the app on a physical device (CloudKit doesn't work fully in Simulator)
2. Ensure you're signed into iCloud on the device
3. Check the console for CloudKit connection status

You can add this test code temporarily to `FishAndChipsApp.swift`:

```swift
import SwiftUI

@main
struct PokerCardRecognizerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    Task {
                        let cloudKit = CloudKitService.shared
                        let status = try? await cloudKit.checkAccountStatus()
                        print("☁️ CloudKit Status: \(String(describing: status))")
                    }
                }
        }
    }
}
```

## Step 8: Verify Everything Works

Run these checks:
- [ ] CloudKit capability is enabled
- [ ] Push Notifications capability is enabled
- [ ] Background Modes are configured
- [ ] Entitlements file is correct
- [ ] CloudKit container exists in Developer Portal
- [ ] CloudKit schema is created in Dashboard
- [ ] App builds without errors
- [ ] CloudKit status check returns `.available`

---

## Troubleshooting

### "CloudKit not available"
- Ensure you're signed into iCloud on your device
- Check that iCloud Drive is enabled
- Verify the container identifier matches exactly

### "Container not found"
- Container creation can take a few minutes
- Try logging out and back into Xcode
- Refresh the CloudKit Dashboard

### Build errors
- Clean build folder (Cmd+Shift+K)
- Delete DerivedData
- Restart Xcode

---

## What's Been Implemented

✅ **CloudKitService.swift** - Basic CloudKit CRUD operations
✅ **CloudKitSyncService.swift** - CoreData ↔ CloudKit synchronization
✅ **CloudKitModels.swift** - CKRecord extensions for all models
✅ **PokerCardRecognizer.entitlements** - Entitlements configuration

## Next Steps After Setup

Once CloudKit is configured and working:
1. Test sync functionality
2. Implement CloudKit subscriptions (Phase 4)
3. Add push notifications
4. Test offline mode

---

**Status**: Manual configuration required
**Estimated Time**: 30-45 minutes
