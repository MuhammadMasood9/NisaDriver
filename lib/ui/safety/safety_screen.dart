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
  final Color accentColor; // Individual accent color for each feature

  SafetyFeature({
    required this.title,
    required this.description,
    required this.iconPath,
    required this.bgIconPath,
    required this.accentColor,
  });
}

class SafetyScreen extends StatelessWidget {
  SafetyScreen({super.key});

  // --- Data for the safety grid ---
  final List<SafetyFeature> safetyFeatures = [
    SafetyFeature(
      title: 'Proactive safety support',
      description:
          'Our system proactively checks in on you during a trip if an unusually long stop is detected. We are here to support you when you need it.',
      iconPath: 'assets/icons/ic_safety_shield.svg',
      bgIconPath: 'assets/icons/ic_green_splotch.svg',
      accentColor: const Color(0xFF4CAF50),
    ),
    SafetyFeature(
      title: 'Passengers verification',
      description:
          'Before accepting a request, check the passenger\'s destination, name, profile picture, and ratings. Accept only the rides that suit you best.',
      iconPath: 'assets/icons/ic_passenger_id.svg',
      bgIconPath: 'assets/icons/ic_green_splotch.svg',
      accentColor: const Color(0xFF2196F3),
    ),
    SafetyFeature(
      title: 'Protecting your privacy',
      description:
          'Your phone number is kept private. All calls and messages between you and the passenger happen through the app to protect your personal information.',
      iconPath: 'assets/icons/ic_privacy_phone.svg',
      bgIconPath: 'assets/icons/ic_green_splotch.svg',
      accentColor: const Color(0xFF9C27B0),
    ),
    SafetyFeature(
      title: 'Staying safe on every ride',
      description:
          'The in-app safety toolkit allows you to share your trip status with loved ones or contact emergency services discreetly.',
      iconPath: 'assets/icons/ic_safety_seatbelt.svg',
      bgIconPath: 'assets/icons/ic_green_splotch.svg',
      accentColor: const Color(0xFFFF9800),
    ),
    SafetyFeature(
      title: 'Accidents: Steps to take',
      description:
          'In the unfortunate event of an accident, find a safe spot, check on everyone involved, and contact emergency services if necessary. Report the incident through the app for assistance.',
      iconPath: 'assets/icons/ic_safety_warning.svg',
      bgIconPath: 'assets/icons/ic_green_splotch.svg',
      accentColor: const Color(0xFFF44336),
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
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildQuickActionsSection(context),
                const SizedBox(height: 24),
                _buildEmergencySection(context),
                const SizedBox(height: 32),
                _buildSafetyFeaturesSection(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the modern app bar with gradient

  /// Builds the quick actions section
  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTypography.h2(context).copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildModernActionCard(
                context,
                icon: Icons.headset_mic_outlined,
                title: 'Support',
                subtitle: 'Get help anytime',
                gradient: const LinearGradient(
                  colors: [AppColors.darkBackground, AppColors.grey700],
                ),
                onTap: () {
                  // TODO: Navigate to Support Screen
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernActionCard(
                context,
                icon: Icons.contacts_outlined,
                title: 'Emergency contacts',
                subtitle: 'Manage contacts',
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.darkModePrimary],
                ),
                onTap: () {
                  // TODO: Navigate to Emergency Contacts Screen
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds modern action cards with gradients
  Widget _buildModernActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.bodyMedium(context).copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodySmall(context).copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the emergency call section
  Widget _buildEmergencySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE53E3E), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53E3E).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE53E3E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(
              Icons.emergency,
              size: 32,
              color: Color(0xFFE53E3E),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Emergency Assistance',
            style: AppTypography.h3(context).copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to call emergency services immediately',
            style: AppTypography.bodyMedium(context).copyWith(
              color: const Color(0xFF718096),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _makeEmergencyCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Call 15',
                    style: AppTypography.buttonlight(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the safety features section
  Widget _buildSafetyFeaturesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How you\'re protected',
          style: AppTypography.h2(context).copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Multiple layers of safety designed to protect you',
          style: AppTypography.bodyMedium(context).copyWith(
            color: const Color(0xFF718096),
          ),
        ),
        const SizedBox(height: 24),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: safetyFeatures.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final feature = safetyFeatures[index];
            return _buildModernSafetyCard(context, feature);
          },
        ),
      ],
    );
  }

  /// Builds a modern safety feature card
  Widget _buildModernSafetyCard(BuildContext context, SafetyFeature feature) {
    return GestureDetector(
      onTap: () => _showModernDetailSheet(context, feature),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: feature.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: feature.accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  // Replace with actual SVG loading
                  Icon(
                    _getIconFromPath(feature.iconPath),
                    size: 24,
                    color: feature.accentColor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: AppTypography.bodyLarge(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.description,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: const Color(0xFF718096),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: const Color(0xFF718096),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to get icon from path (replace with actual SVG loading)
  IconData _getIconFromPath(String path) {
    if (path.contains('shield')) return Icons.shield_outlined;
    if (path.contains('passenger') || path.contains('id'))
      return Icons.badge_outlined;
    if (path.contains('privacy') || path.contains('phone'))
      return Icons.privacy_tip_outlined;
    if (path.contains('seatbelt') || path.contains('safety'))
      return Icons.security_outlined;
    if (path.contains('warning')) return Icons.warning_amber_outlined;
    return Icons.security_outlined;
  }

  /// Shows the modern modal bottom sheet with details
  void _showModernDetailSheet(BuildContext context, SafetyFeature feature) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: feature.accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: feature.accentColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  _getIconFromPath(feature.iconPath),
                                  size: 48,
                                  color: feature.accentColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            feature.title,
                            style: AppTypography.h1(context).copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            feature.description,
                            style: AppTypography.bodyLarge(context).copyWith(
                              color: const Color(0xFF4A5568),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: feature.accentColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This feature is automatically enabled for all rides',
                                    style: AppTypography.bodySmall(context)
                                        .copyWith(
                                      color: const Color(0xFF718096),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
