import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/main.dart';
import 'package:driver/services/localization_service.dart';
import 'package:driver/controller/language_controller.dart';

void main() {
  group('Hardcoded Text Detection Tests', () {
    late Widget app;
    
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      Get.testMode = true;
      
      // Initialize services
      Get.put(LocalizationService());
      Get.put(LanguageController());
      
      app = MyApp();
    });

    tearDown(() {
      Get.reset();
    });

    group('Authentication Screen Hardcoded Text Tests', () {
      testWidgets('should not contain hardcoded English text in Urdu mode - Authentication', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Common authentication-related English words that should not appear
        final authEnglishWords = [
          'Login',
          'Sign In',
          'Sign Up',
          'Register',
          'Email',
          'Password',
          'Confirm Password',
          'Forgot Password',
          'Reset Password',
          'Phone Number',
          'Verify',
          'OTP',
          'Code',
          'Submit',
          'Continue',
          'Back',
          'Next',
          'Terms and Conditions',
          'Privacy Policy',
          'Accept',
          'Agree',
          'Create Account',
          'Already have an account',
          'Don\'t have an account',
        ];
        
        for (final word in authEnglishWords) {
          expect(find.text(word), findsNothing,
            reason: 'Found hardcoded English authentication text "$word" when Urdu is selected');
          
          // Also check for partial matches in longer text
          expect(find.textContaining(word), findsNothing,
            reason: 'Found hardcoded English authentication text containing "$word" when Urdu is selected');
        }
      });
    });

    group('Navigation Hardcoded Text Tests', () {
      testWidgets('should not contain hardcoded English text in Urdu mode - Navigation', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Common navigation-related English words
        final navEnglishWords = [
          'Home',
          'Dashboard',
          'Profile',
          'Settings',
          'Menu',
          'Search',
          'Filter',
          'Sort',
          'Notifications',
          'Messages',
          'Inbox',
          'History',
          'Help',
          'Support',
          'About',
          'Contact',
          'FAQ',
          'Logout',
          'Exit',
          'Close',
          'Cancel',
          'Save',
          'Edit',
          'Delete',
          'Remove',
          'Add',
          'Create',
          'Update',
        ];
        
        for (final word in navEnglishWords) {
          expect(find.text(word), findsNothing,
            reason: 'Found hardcoded English navigation text "$word" when Urdu is selected');
        }
      });
    });

    group('Ride Management Hardcoded Text Tests', () {
      testWidgets('should not contain hardcoded English text in Urdu mode - Ride Management', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Ride management related English words
        final rideEnglishWords = [
          'Book Ride',
          'Request Ride',
          'Start Ride',
          'End Ride',
          'Cancel Ride',
          'Pickup',
          'Drop-off',
          'Destination',
          'Location',
          'Address',
          'Distance',
          'Duration',
          'Fare',
          'Price',
          'Payment',
          'Cash',
          'Card',
          'Wallet',
          'Driver',
          'Passenger',
          'Vehicle',
          'Car',
          'Bike',
          'Route',
          'Map',
          'GPS',
          'Tracking',
          'Status',
          'Waiting',
          'Arrived',
          'In Progress',
          'Completed',
          'Cancelled',
          'Rating',
          'Review',
          'Feedback',
          'Tips',
        ];
        
        for (final word in rideEnglishWords) {
          expect(find.text(word), findsNothing,
            reason: 'Found hardcoded English ride management text "$word" when Urdu is selected');
        }
      });
    });

    group('Financial Hardcoded Text Tests', () {
      testWidgets('should not contain hardcoded English text in Urdu mode - Financial', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Financial related English words
        final financialEnglishWords = [
          'Wallet',
          'Balance',
          'Amount',
          'Total',
          'Subtotal',
          'Tax',
          'Fee',
          'Charge',
          'Discount',
          'Refund',
          'Transaction',
          'Payment',
          'Receipt',
          'Invoice',
          'Bill',
          'Earnings',
          'Income',
          'Withdraw',
          'Deposit',
          'Transfer',
          'Bank',
          'Account',
          'Card',
          'Credit',
          'Debit',
          'Cash',
          'Online',
          'Pending',
          'Completed',
          'Failed',
          'Success',
          'Error',
          'Retry',
        ];
        
        for (final word in financialEnglishWords) {
          expect(find.text(word), findsNothing,
            reason: 'Found hardcoded English financial text "$word" when Urdu is selected');
        }
      });
    });

    group('Error and Status Message Hardcoded Text Tests', () {
      testWidgets('should not contain hardcoded English text in Urdu mode - Error Messages', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Error and status message related English words
        final errorEnglishWords = [
          'Error',
          'Warning',
          'Success',
          'Failed',
          'Loading',
          'Please wait',
          'Try again',
          'Retry',
          'Something went wrong',
          'Network error',
          'Connection failed',
          'Timeout',
          'Invalid',
          'Required',
          'Optional',
          'Mandatory',
          'Missing',
          'Not found',
          'Unauthorized',
          'Forbidden',
          'Server error',
          'Maintenance',
          'Update required',
          'Version',
          'Outdated',
          'Refresh',
          'Reload',
          'Sync',
          'Offline',
          'Online',
          'Connected',
          'Disconnected',
        ];
        
        for (final word in errorEnglishWords) {
          expect(find.text(word), findsNothing,
            reason: 'Found hardcoded English error/status text "$word" when Urdu is selected');
        }
      });
    });

    group('Form and Input Hardcoded Text Tests', () {
      testWidgets('should not contain hardcoded English text in Urdu mode - Forms', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Form and input related English words
        final formEnglishWords = [
          'Name',
          'First Name',
          'Last Name',
          'Full Name',
          'Username',
          'Email',
          'Phone',
          'Mobile',
          'Address',
          'City',
          'State',
          'Country',
          'Postal Code',
          'ZIP Code',
          'Date',
          'Time',
          'Age',
          'Gender',
          'Male',
          'Female',
          'Other',
          'Select',
          'Choose',
          'Pick',
          'Enter',
          'Type',
          'Search',
          'Filter',
          'Sort by',
          'Order by',
          'Ascending',
          'Descending',
          'Clear',
          'Reset',
          'Apply',
          'Confirm',
          'Submit',
          'Send',
          'Upload',
          'Download',
          'Attach',
          'Browse',
          'File',
          'Image',
          'Photo',
          'Video',
          'Document',
        ];
        
        for (final word in formEnglishWords) {
          expect(find.text(word), findsNothing,
            reason: 'Found hardcoded English form text "$word" when Urdu is selected');
        }
      });
    });

    group('Date and Time Hardcoded Text Tests', () {
      testWidgets('should not contain hardcoded English text in Urdu mode - Date/Time', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Date and time related English words
        final dateTimeEnglishWords = [
          'Today',
          'Yesterday',
          'Tomorrow',
          'Now',
          'Later',
          'Soon',
          'Recently',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
          'AM',
          'PM',
          'Morning',
          'Afternoon',
          'Evening',
          'Night',
          'Hour',
          'Minute',
          'Second',
          'Week',
          'Month',
          'Year',
          'Day',
          'Time',
          'Date',
          'Schedule',
          'Calendar',
        ];
        
        for (final word in dateTimeEnglishWords) {
          expect(find.text(word), findsNothing,
            reason: 'Found hardcoded English date/time text "$word" when Urdu is selected');
        }
      });
    });

    group('Communication Hardcoded Text Tests', () {
      testWidgets('should not contain hardcoded English text in Urdu mode - Communication', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Communication related English words
        final commEnglishWords = [
          'Message',
          'Chat',
          'Call',
          'Video Call',
          'Voice Call',
          'Send',
          'Receive',
          'Reply',
          'Forward',
          'Share',
          'Copy',
          'Paste',
          'Cut',
          'Delete',
          'Archive',
          'Mark as read',
          'Mark as unread',
          'Mute',
          'Unmute',
          'Block',
          'Unblock',
          'Report',
          'Contact',
          'Phone Book',
          'Contacts',
          'Add Contact',
          'Remove Contact',
          'Online',
          'Offline',
          'Last seen',
          'Typing',
          'Recording',
          'Delivered',
          'Read',
          'Sent',
          'Failed',
          'Pending',
        ];
        
        for (final word in commEnglishWords) {
          expect(find.text(word), findsNothing,
            reason: 'Found hardcoded English communication text "$word" when Urdu is selected');
        }
      });
    });

    group('Comprehensive Text Widget Scan', () {
      testWidgets('should scan all Text widgets for hardcoded English content', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Get all Text widgets
        final textWidgets = find.byType(Text);
        final List<String> suspiciousTexts = [];
        
        for (final textWidget in textWidgets.evaluate()) {
          final text = textWidget.widget as Text;
          final textData = text.data;
          
          if (textData != null && textData.isNotEmpty) {
            // Check if text contains only English characters (basic check)
            final hasOnlyEnglish = RegExp(r'^[a-zA-Z0-9\s\.,!?;:\'"-]+$').hasMatch(textData);
            final isLikelyEnglishWord = RegExp(r'\b[A-Z][a-z]+\b').hasMatch(textData);
            
            if (hasOnlyEnglish && isLikelyEnglishWord && textData.length > 2) {
              // Skip common acceptable English text (numbers, symbols, etc.)
              if (!_isAcceptableEnglishText(textData)) {
                suspiciousTexts.add(textData);
              }
            }
          }
        }
        
        // Log suspicious texts for debugging
        if (suspiciousTexts.isNotEmpty) {
          print('Suspicious English texts found in Urdu mode:');
          for (final text in suspiciousTexts.take(20)) { // Limit output
            print('  - "$text"');
          }
          if (suspiciousTexts.length > 20) {
            print('  ... and ${suspiciousTexts.length - 20} more');
          }
        }
        
        // Allow some English text (like app names, technical terms)
        expect(suspiciousTexts.length, lessThan(10),
          reason: 'Found ${suspiciousTexts.length} suspicious English texts in Urdu mode. First few: ${suspiciousTexts.take(5).join(", ")}');
      });
    });

    group('Button and Action Text Tests', () {
      testWidgets('should not contain hardcoded English text in buttons when Urdu is selected', (WidgetTester tester) async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        
        final languageController = Get.find<LanguageController>();
        await languageController.changeLanguage('ur');
        await tester.pumpAndSettle();
        
        // Common button text in English
        final buttonEnglishWords = [
          'OK',
          'Cancel',
          'Yes',
          'No',
          'Accept',
          'Decline',
          'Agree',
          'Disagree',
          'Continue',
          'Skip',
          'Next',
          'Previous',
          'Back',
          'Forward',
          'Submit',
          'Send',
          'Save',
          'Delete',
          'Edit',
          'Update',
          'Create',
          'Add',
          'Remove',
          'Clear',
          'Reset',
          'Refresh',
          'Reload',
          'Retry',
          'Close',
          'Open',
          'Start',
          'Stop',
          'Pause',
          'Resume',
          'Play',
          'Record',
          'Upload',
          'Download',
          'Share',
          'Copy',
          'Paste',
          'Cut',
        ];
        
        // Check for buttons with English text
        for (final word in buttonEnglishWords) {
          final buttonFinder = find.widgetWithText(ElevatedButton, word);
          expect(buttonFinder, findsNothing,
            reason: 'Found ElevatedButton with hardcoded English text "$word" when Urdu is selected');
          
          final textButtonFinder = find.widgetWithText(TextButton, word);
          expect(textButtonFinder, findsNothing,
            reason: 'Found TextButton with hardcoded English text "$word" when Urdu is selected');
          
          final outlinedButtonFinder = find.widgetWithText(OutlinedButton, word);
          expect(outlinedButtonFinder, findsNothing,
            reason: 'Found OutlinedButton with hardcoded English text "$word" when Urdu is selected');
        }
      });
    });
  });

  /// Helper function to determine if English text is acceptable
  /// (e.g., version numbers, technical identifiers, etc.)
  bool _isAcceptableEnglishText(String text) {
    // Version numbers
    if (RegExp(r'^\d+\.\d+(\.\d+)?$').hasMatch(text)) return true;
    
    // Single characters or very short text
    if (text.length <= 2) return true;
    
    // Numbers with units
    if (RegExp(r'^\d+\s*(km|m|kg|g|%|$)$').hasMatch(text)) return true;
    
    // Technical identifiers (UUIDs, codes, etc.)
    if (RegExp(r'^[A-Z0-9_-]+$').hasMatch(text)) return true;
    
    // URLs or email patterns
    if (text.contains('@') || text.contains('http') || text.contains('www')) return true;
    
    // File extensions
    if (RegExp(r'\.(jpg|png|pdf|doc|txt)$').hasMatch(text.toLowerCase())) return true;
    
    // Common abbreviations that might be acceptable
    final acceptableAbbreviations = ['GPS', 'SMS', 'OTP', 'API', 'URL', 'ID', 'QR'];
    if (acceptableAbbreviations.contains(text.toUpperCase())) return true;
    
    return false;
  }
}