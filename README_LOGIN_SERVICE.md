# NisaDriver Login Service

This document explains how to use the new login service that provides persistent login functionality for the NisaDriver app.

## Overview

The new login service (`LoginService`) provides:
- Persistent login using SharedPreferences
- Integration with Firebase Auth
- Support for multiple authentication methods (email/password, phone, Google, Apple)
- Automatic login state management
- Fallback to stored credentials when Firebase Auth is not immediately available

## Key Features

### 1. Persistent Login
- Users stay logged in even after closing and reopening the app
- Login state is stored in SharedPreferences
- Automatic fallback to stored credentials

### 2. Multiple Authentication Methods
- **Email/Password**: Traditional email and password authentication
- **Phone Number**: SMS OTP verification
- **Google Sign-In**: Google account authentication
- **Apple Sign-In**: Apple ID authentication (iOS)

### 3. Automatic State Management
- Listens to Firebase Auth state changes
- Updates SharedPreferences automatically
- Handles user profile updates

## Usage

### Initialization

The service is automatically initialized in `main.dart`:

```dart
void main() async {
  // ... other initialization code ...
  
  // Initialize LoginService for login persistence
  await LoginService.initialize();
  
  // ... rest of initialization ...
}
```

### Checking Login Status

```dart
// Check if user is currently logged in
bool isLoggedIn = await LoginService.isLoggedIn();

if (isLoggedIn) {
  // User is logged in, navigate to dashboard
  Get.offAll(const DashBoardScreen());
} else {
  // User is not logged in, navigate to login screen
  Get.offAll(const LoginScreen());
}
```

### Email/Password Authentication

```dart
// Sign in with email and password
UserCredential? credential = await LoginService.signInWithEmailAndPassword(
  email: 'driver@example.com',
  password: 'password123'
);

if (credential != null) {
  // Login successful
  Get.offAll(const DashBoardScreen());
} else {
  // Login failed
  ShowToastDialog.showToast('Login failed');
}
```

### Phone Number Authentication

```dart
// Send verification code
await LoginService.signInWithPhoneNumber(
  phoneNumber: '+1234567890',
  onCodeSent: (String verificationId) {
    // Navigate to OTP screen
    Get.to(const OtpScreen(), arguments: {
      'verificationId': verificationId,
      'phoneNumber': '+1234567890',
    });
  },
  onVerificationFailed: (FirebaseAuthException e) {
    ShowToastDialog.showToast('Verification failed: ${e.message}');
  },
);

// Verify OTP
UserCredential? credential = await LoginService.verifyOTP(
  verificationId: verificationId,
  smsCode: '123456'
);
```

### Google Sign-In

```dart
UserCredential? credential = await LoginService.signInWithGoogle();

if (credential != null) {
  // Google sign-in successful
  Get.offAll(const DashBoardScreen());
} else {
  // Google sign-in failed or canceled
  ShowToastDialog.showToast('Google sign-in failed');
}
```

### Apple Sign-In

```dart
UserCredential? credential = await LoginService.signInWithApple();

if (credential != null) {
  // Apple sign-in successful
  Get.offAll(const DashBoardScreen());
} else {
  // Apple sign-in failed or canceled
  ShowToastDialog.showToast('Apple sign-in failed');
}
```

### Sign Out

```dart
await LoginService.signOut();
// User will be automatically redirected to login screen
```

### Getting Current User

```dart
// Get current Firebase user
User? currentUser = LoginService.currentUser;

// Get current driver user model
DriverUserModel? driverUser = await LoginService.getCurrentDriverUser();
```

## Integration with Existing Code

### Splash Controller

The splash controller now uses the new service:

```dart
class SplashController extends GetxController {
  redirectScreen() async {
    // Use LoginService for robust login checking with shared preferences
    bool isLogin = await LoginService.isLoggedIn();
    if (isLogin) {
      Get.offAll(const DashBoardScreen());
    } else {
      Get.offAll(const LoginScreen());
    }
  }
}
```

### FireStoreUtils

The `isLogin()` method in FireStoreUtils now uses the new service:

```dart
static Future<bool> isLogin() async {
  try {
    // Use the new LoginService for robust login checking
    return await LoginService.isLoggedIn();
  } catch (e) {
    print('Error in isLogin: $e');
    // Fallback to Firebase Auth check
    return FirebaseAuth.instance.currentUser != null;
  }
}
```

## SharedPreferences Keys

The service uses the following keys for storing login data:

- `driver_is_logged_in`: Boolean indicating if user is logged in
- `driver_user_id`: User's Firebase UID
- `driver_user_email`: User's email address
- `driver_user_phone`: User's phone number
- `driver_user_data`: JSON string of user data from Firestore
- `driver_login_type`: Type of login method used

## Error Handling

The service includes comprehensive error handling:

- Firebase Auth exceptions are caught and converted to user-friendly messages
- Network errors are handled gracefully
- Fallback mechanisms ensure the app doesn't crash
- All errors are logged for debugging

## Benefits

1. **Improved User Experience**: Users don't need to log in every time they open the app
2. **Reliable Authentication**: Multiple fallback mechanisms ensure authentication works
3. **Better Performance**: Faster app startup with cached credentials
4. **Consistent Behavior**: Same login behavior across different app states
5. **Easy Integration**: Drop-in replacement for existing authentication code

## Troubleshooting

### Common Issues

1. **User always redirected to login**: Check if SharedPreferences are properly initialized
2. **Firebase Auth errors**: Verify Firebase configuration and network connectivity
3. **SharedPreferences errors**: Ensure the package is properly added to pubspec.yaml

### Debug Information

Enable debug logging by checking the console output. The service logs all important operations and errors.

## Migration from Old System

The new service is designed to be a drop-in replacement. Simply:

1. Replace `FireStoreUtils.isLogin()` calls with `LoginService.isLoggedIn()`
2. Update authentication method calls to use the new service
3. The service will automatically handle the migration of existing login data

## Future Enhancements

- Biometric authentication support
- Multi-factor authentication
- Session management and timeout
- Offline authentication support
