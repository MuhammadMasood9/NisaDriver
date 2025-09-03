import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:get/get.dart';

class LoginService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Shared preferences keys
  static const String _keyIsLoggedIn = 'driver_is_logged_in';
  static const String _keyUserId = 'driver_user_id';
  static const String _keyUserEmail = 'driver_user_email';
  static const String _keyUserPhone = 'driver_user_phone';
  static const String _keyUserData = 'driver_user_data';

  // Stream controller for auth state changes
  static final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Get auth state stream
  static Stream<User?> get authStateChanges => _authStateController.stream;

  // Initialize login service
  static Future<void> initialize() async {
    try {
      print('LoginService: Initializing...');
      // Listen to auth state changes
      _auth.authStateChanges().listen((User? user) {
        print(
            'LoginService: Auth state changed - User: ${user?.uid ?? 'null'}');
        _authStateController.add(user);
        _updateLoginStatus(user);
      });
      print('LoginService: Initialized successfully');
    } catch (e) {
      print('LoginService: Error during initialization: $e');
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      print('LoginService: Checking login status...');

      // First check Firebase Auth
      User? user = _auth.currentUser;
      print('LoginService: Firebase Auth current user: ${user?.uid ?? 'null'}');

      if (user == null) {
        // Check shared preferences as fallback
        bool fromPrefs = await isLoggedInFromPrefs();
        print('LoginService: No Firebase user, checking prefs: $fromPrefs');
        return fromPrefs;
      }

      // Check if user exists in Firestore
      bool userExists = await _checkUserExists(user.uid);
      print('LoginService: User exists in Firestore: $userExists');

      if (!userExists) {
        // User doesn't exist in Firestore, sign out
        print('LoginService: User not in Firestore, signing out');
        await signOut();
        return false;
      }

      // Update shared preferences
      await _updateLoginStatus(user);
      print('LoginService: User is logged in and valid');
      return true;
    } catch (e) {
      print('LoginService: Error checking login status: $e');
      // Fallback to shared preferences
      try {
        bool fromPrefs = await isLoggedInFromPrefs();
        print('LoginService: Fallback to prefs: $fromPrefs');
        return fromPrefs;
      } catch (prefError) {
        print('LoginService: Error checking prefs: $prefError');
        return false;
      }
    }
  }

  // Check if user exists in Firestore
  static Future<bool> _checkUserExists(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(CollectionName.driverUsers)
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e) {
      print('LoginService: Error checking user existence: $e');
      return false;
    }
  }

  // Sign in with email and password
  static Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      ShowToastDialog.showLoader("Please wait".tr);

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        print(
            'LoginService: Email sign-in successful for user: ${userCredential.user!.uid}');
        await _updateLoginStatus(userCredential.user);
        ShowToastDialog.closeLoader();
        return userCredential;
      }

      ShowToastDialog.closeLoader();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      ShowToastDialog.closeLoader();
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "No user found for that email.".tr;
          break;
        case 'wrong-password':
          errorMessage = "Wrong password provided.".tr;
          break;
        case 'invalid-email':
          errorMessage = "The email address is invalid.".tr;
          break;
        case 'user-disabled':
          errorMessage = "This user account has been disabled.".tr;
          break;
        default:
          errorMessage = e.message ?? "An error occurred during login.".tr;
      }
      ShowToastDialog.showToast(errorMessage);
      return null;
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Login failed: $e".tr);
      return null;
    }
  }

  // Sign in with phone number
  static Future<void> signInWithPhoneNumber(
      String phoneNumber,
      PhoneCodeSent onCodeSent,
      PhoneVerificationFailed onVerificationFailed) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          UserCredential userCredential =
              await _auth.signInWithCredential(credential);
          if (userCredential.user != null) {
            await _updateLoginStatus(userCredential.user);
          }
        },
        verificationFailed: onVerificationFailed,
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Code auto retrieval timeout');
        },
      );
    } catch (e) {
      print('Error sending verification code: $e');
      rethrow;
    }
  }

  // Verify OTP
  static Future<UserCredential?> verifyOTP(
      String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _updateLoginStatus(userCredential.user);
      }

      return userCredential;
    } catch (e) {
      print('Error verifying OTP: $e');
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      print('LoginService: Signing out user');
      await _auth.signOut();
      await _clearLoginStatus();
      print('LoginService: User signed out successfully');
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Update login status in shared preferences
  static Future<void> _updateLoginStatus(User? user) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      if (user != null) {
        print('LoginService: Updating login status for user: ${user.uid}');
        await prefs.setBool(_keyIsLoggedIn, true);
        await prefs.setString(_keyUserId, user.uid);
        await prefs.setString(_keyUserEmail, user.email ?? '');
        await prefs.setString(_keyUserPhone, user.phoneNumber ?? '');

        // Store user data if available
        if (user.uid.isNotEmpty) {
          try {
            DocumentSnapshot doc = await _firestore
                .collection(CollectionName.driverUsers)
                .doc(user.uid)
                .get();

            if (doc.exists && doc.data() != null) {
              String userData = jsonEncode(doc.data());
              await prefs.setString(_keyUserData, userData);
              print('LoginService: User data stored in prefs');
            }
          } catch (e) {
            print('Error storing user data: $e');
          }
        }
      } else {
        print('LoginService: Clearing login status');
        await _clearLoginStatus();
      }
    } catch (e) {
      print('Error updating login status: $e');
    }
  }

  // Clear login status from shared preferences
  static Future<void> _clearLoginStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserPhone);
      await prefs.remove(_keyUserData);
      print('LoginService: Login status cleared from prefs');
    } catch (e) {
      print('Error clearing login status: $e');
    }
  }

  // Get stored user ID
  static Future<String?> getStoredUserId() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserId);
    } catch (e) {
      print('Error getting stored user ID: $e');
      return null;
    }
  }

  // Get stored user email
  static Future<String?> getStoredUserEmail() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserEmail);
    } catch (e) {
      print('Error getting stored user email: $e');
      return null;
    }
  }

  // Get stored user phone
  static Future<String?> getStoredUserPhone() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserPhone);
    } catch (e) {
      print('Error getting stored user phone: $e');
      return null;
    }
  }

  // Check if user is logged in from shared preferences
  static Future<bool> isLoggedInFromPrefs() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      print('LoginService: Checking prefs for login status: $isLoggedIn');
      return isLoggedIn;
    } catch (e) {
      print('Error checking login status from prefs: $e');
      return false;
    }
  }

  // Get current driver user model
  static Future<DriverUserModel?> getCurrentDriverUser() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return null;

      DocumentSnapshot doc = await _firestore
          .collection(CollectionName.driverUsers)
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        return DriverUserModel.fromJson(doc.data() as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      print('Error getting current driver user: $e');
      return null;
    }
  }

  // Update driver user profile
  static Future<bool> updateDriverProfile(DriverUserModel driverUser) async {
    try {
      await _firestore
          .collection(CollectionName.driverUsers)
          .doc(driverUser.id)
          .set(driverUser.toJson());

      // Update stored user data
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserData, jsonEncode(driverUser.toJson()));

      return true;
    } catch (e) {
      print('Error updating driver profile: $e');
      return false;
    }
  }

  // Public method to update login status (for external use)
  static Future<void> updateLoginStatus(User? user) async {
    await _updateLoginStatus(user);
  }

  // Dispose resources
  static void dispose() {
    _authStateController.close();
  }

  // Test method to verify service is working
  static Future<bool> testService() async {
    try {
      print('LoginService: Testing service...');

      // Test SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_key', 'test_value');
      String? testValue = prefs.getString('test_key');
      await prefs.remove('test_key');

      if (testValue == 'test_value') {
        print('LoginService: SharedPreferences test passed');
      } else {
        print('LoginService: SharedPreferences test failed');
        return false;
      }

      // Test Firebase Auth
      User? currentUser = _auth.currentUser;
      print(
          'LoginService: Firebase Auth test - Current user: ${currentUser?.uid ?? 'null'}');

      print('LoginService: Service test completed successfully');
      return true;
    } catch (e) {
      print('LoginService: Service test failed: $e');
      return false;
    }
  }
}
