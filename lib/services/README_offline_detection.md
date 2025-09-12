# Automatic Offline Detection System

## Overview
This system automatically manages driver online/offline status based on app lifecycle:

- **ONLINE**: When app is running (foreground OR background)
- **OFFLINE**: When app is completely terminated/closed

## How It Works

### 1. Client-Side (Flutter App)
- **AppLifecycleService** monitors app state changes
- Sends heartbeat every 30 seconds to Firestore
- Updates `lastHeartbeat` and `appInForeground` fields
- Keeps driver online when app goes to background
- Sets driver offline only when app is terminated

### 2. Server-Side (Cloud Function - Optional)
Deploy this cloud function to automatically detect terminated apps:

```javascript
// Cloud Function (Firebase Functions)
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.checkDriverStatus = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const twoMinutesAgo = new Date(now.toDate().getTime() - 2 * 60 * 1000);
    
    try {
      // Find drivers who haven't sent heartbeat in 2+ minutes and are still online
      const driversQuery = await db.collection('drivers')
        .where('isOnline', '==', true)
        .where('lastHeartbeat', '<', admin.firestore.Timestamp.fromDate(twoMinutesAgo))
        .get();
      
      const batch = db.batch();
      let count = 0;
      
      driversQuery.forEach((doc) => {
        batch.update(doc.ref, {
          isOnline: false,
          lastStatusChange: now,
          statusChangeReason: 'app_terminated'
        });
        count++;
      });
      
      if (count > 0) {
        await batch.commit();
        console.log(`Set ${count} drivers offline due to app termination`);
      }
      
      return null;
    } catch (error) {
      console.error('Error checking driver status:', error);
      return null;
    }
  });
```

### 3. Firestore Security Rules
Add these rules to ensure proper access:

```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /drivers/{driverId} {
      allow read, write: if request.auth != null && request.auth.uid == driverId;
      
      // Allow heartbeat updates
      allow update: if request.auth != null 
        && request.auth.uid == driverId
        && request.writeFields.hasOnly(['lastHeartbeat', 'appInForeground', 'isOnline']);
    }
  }
}
```

## Implementation Steps

### 1. Client-Side Setup (Already Done)
- ✅ AppLifecycleService created
- ✅ Integrated with main.dart
- ✅ Dashboard controller updated
- ✅ Heartbeat system implemented

### 2. Server-Side Setup (Optional but Recommended)
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Initialize functions: `firebase init functions`
3. Add the cloud function code above
4. Deploy: `firebase deploy --only functions`

### 3. Testing
1. **Foreground to Background**: Driver should stay online
2. **Background to Foreground**: Driver should remain online
3. **App Termination**: Driver should go offline (after 2 minutes if using cloud function)
4. **Manual Toggle**: Should work as before

## Behavior Summary

| App State | Driver Status | Notes |
|-----------|---------------|-------|
| Foreground | Online | Normal operation |
| Background | Online | Can receive ride requests |
| Terminated | Offline | Detected by missing heartbeat |
| Manual Toggle | User Choice | Overrides automatic behavior |

## Benefits

1. **Better User Experience**: Drivers stay online when app is backgrounded
2. **Accurate Status**: Automatic offline detection when app is closed
3. **Resource Efficient**: Minimal battery/data usage
4. **Reliable**: Works even if app crashes or is force-closed
5. **Scalable**: Server-side detection handles thousands of drivers

## Monitoring

You can monitor the system by checking:
- `lastHeartbeat` field in driver documents
- `appInForeground` boolean field
- Cloud function logs (if implemented)