import 'package:driver/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:story_view/story_view.dart';
import 'package:url_launcher/url_launcher.dart';

// Assuming this class exists. If not, you can remove the import and this class.
class AppTypography {
  static TextStyle appTitle(BuildContext context) {
    return const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );
  }
}

// Data model for each safety feature
class SafetyFeature {
  final String title;
  final String iconPath;
  final String popupImagePath;
  final String popupTitle;
  final String popupDescription;

  SafetyFeature({
    required this.title,
    required this.iconPath,
    required this.popupImagePath,
    required this.popupTitle,
    required this.popupDescription,
  });
}

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  // List of safety features with their corresponding popup data
  static final List<SafetyFeature> safetyFeatures = [
    SafetyFeature(
      title: "Proactive safety support".tr,
      iconPath: 'assets/images/Protecting.png',
      popupImagePath:
          'assets/images/Protecting.png', // Replace with a relevant image
      popupTitle: "We've got your back".tr,
      popupDescription:
          "Our system proactively checks in on you if we detect any unusual activity during your ride, like a long, unexpected stop.".tr,
    ),
    SafetyFeature(
      title: "Passengers verification".tr,
      iconPath: 'assets/images/Verfication.png',
      popupImagePath:
          'assets/images/Verfication.png', // This is the image from your screenshot
      popupTitle: "Choose your passenger".tr,
      popupDescription:
          "Before accepting a request, check the passenger's destination, name, profile picture, and ratings. Accept only the rides that suit you best.".tr,
    ),
    SafetyFeature(
      title: "Protecting your privacy".tr,
      iconPath: 'assets/images/Safety-Support.png',
      popupImagePath:
          'assets/images/Safety-Support.png', // Replace with a relevant image
      popupTitle: "Your details are private".tr,
      popupDescription:
          "Your phone number is anonymized when you call or text through the app, so your personal contact information stays private.".tr,
    ),
    SafetyFeature(
      title: "Staying safe on every ride".tr,
      iconPath: 'assets/images/Every-Ride.png',
      popupImagePath:
          'assets/images/Every-Ride.png', // Replace with a relevant image
      popupTitle: "Safety for every journey".tr,
      popupDescription:
          "From GPS tracking to our 24/7 support team, we have features in place to help you stay safe from pickup to drop-off.".tr,
    ),
    SafetyFeature(
      title: "Accidents: Steps to take".tr,
      iconPath: 'assets/images/Accident.png',
      popupImagePath:
          'assets/images/Accident.png', // Replace with a relevant image
      popupTitle: "In case of an accident".tr,
      popupDescription:
          "If you're involved in an accident, first ensure your safety and call local emergency services if needed. You can then report the incident to us directly through the app.".tr,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Added SafeArea to keep content below status bar
            const SafeArea(
              bottom: false,
              child: SizedBox.shrink(),
            ),
            _buildTopActions(context),
            const SizedBox(height: 24),
            _buildEmergencyCallButton(),
            const SizedBox(height: 32),
            const Text(
              "How you're protected",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildFeaturesGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildTopActionCard(
            context: context,
            title: "Support and backup".tr,
            iconPath: 'assets/images/Protecting.png',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTopActionCard(
            context: context,
            title: "Emergency contacts".tr,
            iconPath: 'assets/images/Protecting.png',
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildTopActionCard({
    required BuildContext context,
    required String title,
    required String iconPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(iconPath, height: 28, width: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCallButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final Uri launchUri = Uri(scheme: 'tel', path: '15');
          if (await canLaunchUrl(launchUri)) {
            await launchUrl(launchUri);
          } else {
            // It's good practice to show feedback to the user
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(content: Text('Could not launch emergency call')),
            // );
            print('Could not launch $launchUri');
          }
        },
        icon: const Icon(Icons.call, size: 20),
        label: const Text(
          "Call 15",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: safetyFeatures.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        final feature = safetyFeatures[index];
        return _buildFeatureCard(
          context: context,
          feature: feature,
          onTap: () {
            // Navigate to the new story viewer screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SafetyStoryViewer(
                  features: safetyFeatures,
                  initialIndex: index,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required SafetyFeature feature,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    feature.title,
                    style: AppTypography.appTitle(context),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Image.asset(feature.iconPath, height: 50, width: 50),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// WIDGET FOR STORY VIEWING
class SafetyStoryViewer extends StatefulWidget {
  final List<SafetyFeature> features;
  final int initialIndex;

  const SafetyStoryViewer({
    super.key,
    required this.features,
    required this.initialIndex,
  });

  @override
  State<SafetyStoryViewer> createState() => _SafetyStoryViewerState();
}

class _SafetyStoryViewerState extends State<SafetyStoryViewer> {
  final StoryController _storyController = StoryController();
  late List<StoryItem> _storyItems;

  @override
  void initState() {
    super.initState();

    final reorderedFeatures = List<SafetyFeature>.from(widget.features);
    final tappedFeature = reorderedFeatures.removeAt(widget.initialIndex);
    reorderedFeatures.insert(0, tappedFeature);

    _storyItems = reorderedFeatures.map((feature) {
      // Pass the custom widget as the first POSITIONAL argument to StoryItem.
      return StoryItem(
        _StoryPageLayout(feature: feature, storyController: _storyController),
        duration: const Duration(
            seconds: 3), // Changed to 3 seconds like Instagram/WhatsApp
      );
    }).toList();
  }

  @override
  void dispose() {
    _storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StoryView(
        storyItems: _storyItems,
        controller: _storyController,
        onComplete: () => Navigator.of(context).pop(),
        onVerticalSwipeComplete: (direction) {
          if (direction == Direction.down) {
            Navigator.of(context).pop();
          }
        },
        onStoryShow: (storyItem, index) {
          // Optional: Add haptic feedback when story changes
          // HapticFeedback.lightImpact();
        },
        progressPosition: ProgressPosition.top,
        repeat: false,
        inline: false,
      ),
    );
  }
}

// WIDGET FOR THE LAYOUT OF A SINGLE STORY PAGE
class _StoryPageLayout extends StatelessWidget {
  final SafetyFeature feature;
  final StoryController storyController;

  const _StoryPageLayout({
    required this.feature,
    required this.storyController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1a1a1a),
            Color(0xFF2d2d2d),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            const SizedBox(height: 40),

            // Main content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with rounded container
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        feature.popupImagePath,
                        height: 120,
                        width: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  Text(
                    feature.popupTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    feature.popupDescription,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom indicator
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swipe_down,
                      color: Colors.white.withOpacity(0.6),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Swipe down to close',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
