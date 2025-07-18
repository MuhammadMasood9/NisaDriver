import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

// Data model for a safety feature item
class SafetyFeature {
  final String title;
  final String description;
  final String iconPath; // Main icon (e.g., shield, ID card)
  final String bgIconPath; // Background splotch icon

  SafetyFeature({
    required this.title,
    required this.description,
    required this.iconPath,
    required this.bgIconPath,
  });
}

class SafetyScreen extends StatelessWidget {
  SafetyScreen({super.key});

  // --- Data for the safety grid ---
  // TODO: Replace 'assets/icons/...' with your actual SVG asset paths.
  final List<SafetyFeature> safetyFeatures = [
    SafetyFeature(
      title: 'Proactive safety support',
      description: 'Our system proactively checks in on you during a trip if an unusually long stop is detected. We are here to support you when you need it.',
      iconPath: 'assets/icons/ic_safety_shield.svg',
      bgIconPath: 'assets/icons/ic_green_splotch.svg',
    ),
    SafetyFeature(
      title: 'Passengers verification',
      description: 'Before accepting a request, check the passenger\'s destination, name, profile picture, and ratings. Accept only the rides that suit you best.',
      iconPath: 'assets/icons/ic_passenger_id.svg',
      bgIconPath: 'assets/icons/ic_green_splotch.svg',
    ),
    SafetyFeature(
      title: 'Protecting your privacy',
      description: 'Your phone number is kept private. All calls and messages between you and the passenger happen through the app to protect your personal information.',
      iconPath: 'assets/icons/ic_privacy_phone.svg',
      bgIconPath: 'assets/icons/ic_green_splotch.svg',
    ),
    SafetyFeature(
      title: 'Staying safe on every ride',
      description: 'The in-app safety toolkit allows you to share your trip status with loved ones or contact emergency services discreetly.',
      iconPath: 'assets/icons/ic_safety_seatbelt.svg',
      bgIconPath: 'assets/icons/ic_green_splotch.svg',
    ),
    SafetyFeature(
      title: 'Accidents: Steps to take',
      description: 'In the unfortunate event of an accident, find a safe spot, check on everyone involved, and contact emergency services if necessary. Report the incident through the app for assistance.',
      iconPath: 'assets/icons/ic_safety_warning.svg',
      bgIconPath: 'assets/icons/ic_green_splotch.svg',
    ),
  ];

  /// Function to launch the phone dialer
  Future<void> _makeEmergencyCall() async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: '15', // Emergency number
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      // Show an error message if the call cannot be made
      Get.snackbar(
        'Error',
        'Could not place the call.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopActionCards(context),
            const SizedBox(height: 20),
            _buildEmergencyCallButton(),
            const SizedBox(height: 30),
            Text(
              "How you're protected",
              style: AppTypography.h2(context),
            ),
            const SizedBox(height: 16),
            _buildProtectionGrid(context),
          ],
        ),
      ),
    );
  }

  /// Builds the top row of cards (Support, Emergency contacts)
  Widget _buildTopActionCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            context,
            icon: Icons.support_agent_outlined,
            title: 'Support',
            onTap: () {
              // TODO: Navigate to Support Screen
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            context,
            icon: Icons.group_outlined,
            title: 'Emergency contacts',
            onTap: () {
              // TODO: Navigate to Emergency Contacts Screen
            },
          ),
        ),
      ],
    );
  }

  /// Helper to create individual info cards
  Widget _buildInfoCard(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.bodyMedium(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the red "Call 15" button
  Widget _buildEmergencyCallButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _makeEmergencyCall,
        icon: const Icon(Icons.local_police_outlined, color: Colors.white),
        label: Text(
          'Call 15',
          style: AppTypography.buttonlight(Get.context!),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xffD93434), // A standard emergency red
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  /// Builds the grid of protection features
  Widget _buildProtectionGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: safetyFeatures.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9, // Adjust ratio to fit content
      ),
      itemBuilder: (context, index) {
        final feature = safetyFeatures[index];
        return _buildProtectionItem(context, feature);
      },
    );
  }

  /// Builds a single item for the protection grid
  Widget _buildProtectionItem(BuildContext context, SafetyFeature feature) {
    return GestureDetector(
      onTap: () => _showProtectionDetailSheet(context, feature),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              feature.title,
              style: AppTypography.bodyMedium(context).copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background Splotch
                  SvgPicture.asset(
                    feature.bgIconPath,
                    width: 70, // Adjust size as needed
                    height: 70,
                  ),
                  // Foreground Icon
                  SvgPicture.asset(
                    feature.iconPath,
                    width: 40, // Adjust size as needed
                    height: 40,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the modal bottom sheet with details about the safety feature
  void _showProtectionDetailSheet(BuildContext context, SafetyFeature feature) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25.0),
              topRight: Radius.circular(25.0),
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60), // Space for icon
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SvgPicture.asset(feature.bgIconPath, height: 120),
                          SvgPicture.asset(feature.iconPath, height: 90, colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      feature.title,
                      style: AppTypography.h1(context),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      feature.description,
                      style: AppTypography.bodyLarge(context).copyWith(
                        color: Colors.black54,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}