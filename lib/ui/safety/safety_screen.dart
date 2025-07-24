import 'package:flutter/material.dart';
import 'package:story_view/story_view.dart';
import 'package:url_launcher/url_launcher.dart';

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
  const SafetyScreen({Key? key}) : super(key: key);

  // List of safety features with their corresponding popup data
  // NOTE: I've updated the popupImagePath to use the user-provided screenshot for one of the items
  // to better demonstrate the new UI. You can create different images for each feature.
  static final List<SafetyFeature> safetyFeatures = [
    SafetyFeature(
      title: "Proactive safety support",
      iconPath: 'assets/images/safety_shield.png',
      popupImagePath:
          'assets/images/popup_choose_passenger.png', // Replace with a relevant image
      popupTitle: "We've got your back",
      popupDescription:
          "Our system proactively checks in on you if we detect any unusual activity during your ride, like a long, unexpected stop.",
    ),
    SafetyFeature(
      title: "Passengers verification",
      iconPath: 'assets/images/safety_verification.png',
      popupImagePath:
          'assets/images/popup_choose_passenger.png', // This is the image from your screenshot
      popupTitle: "Choose your passenger",
      popupDescription:
          "Before accepting a request, check the passenger's destination, name, profile picture, and ratings. Accept only the rides that suit you best.",
    ),
    SafetyFeature(
      title: "Protecting your privacy",
      iconPath: 'assets/images/safety_privacy.png',
      popupImagePath:
          'assets/images/popup_choose_passenger.png', // Replace with a relevant image
      popupTitle: "Your details are private",
      popupDescription:
          "Your phone number is anonymized when you call or text through the app, so your personal contact information stays private.",
    ),
    SafetyFeature(
      title: "Staying safe on every ride",
      iconPath: 'assets/images/safety_safe_ride.png',
      popupImagePath:
          'assets/images/popup_choose_passenger.png', // Replace with a relevant image
      popupTitle: "Safety for every journey",
      popupDescription:
          "From GPS tracking to our 24/7 support team, we have features in place to help you stay safe from pickup to drop-off.",
    ),
    SafetyFeature(
      title: "Accidents: Steps to take",
      iconPath: 'assets/images/safety_accident.png',
      popupImagePath:
          'assets/images/popup_choose_passenger.png', // Replace with a relevant image
      popupTitle: "In case of an accident",
      popupDescription:
          "If you're involved in an accident, first ensure your safety and call local emergency services if needed. You can then report the incident to us directly through the app.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {
            // TODO: Implement drawer or navigation
          },
        ),
        title: const Text(
          "Safety",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            title: "Support",
            iconPath: 'assets/images/safety_support.png',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTopActionCard(
            context: context,
            title: "Emergency contacts",
            iconPath: 'assets/images/safety_emergency_contacts.png',
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
          backgroundColor: const Color(0xFFD32F2F),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
            Positioned(
              bottom: -15,
              right: -15,
              child: Image.asset(
                'assets/images/safety_green_splash.png',
                height: 80,
                width: 80,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    feature.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Image.asset(feature.iconPath, height: 32, width: 32),
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

// NEW WIDGET FOR STORY VIEWING
class SafetyStoryViewer extends StatefulWidget {
  final List<SafetyFeature> features;
  final int initialIndex;

  const SafetyStoryViewer({
    Key? key,
    required this.features,
    required this.initialIndex,
  }) : super(key: key);

  @override
  _SafetyStoryViewerState createState() => _SafetyStoryViewerState();
}

class _SafetyStoryViewerState extends State<SafetyStoryViewer> {
  final StoryController _storyController = StoryController();
  late List<StoryItem> _storyItems;

  @override
  void initState() {
    super.initState();

    // Reorder the feature list to start with the item that was tapped
    final reorderedFeatures = List<SafetyFeature>.from(widget.features);
    final tappedFeature = reorderedFeatures.removeAt(widget.initialIndex);
    reorderedFeatures.insert(0, tappedFeature);

    // Create a StoryItem for each feature
    _storyItems = reorderedFeatures.map((feature) {
      return StoryItem.pageImage(
        url: feature.popupImagePath, // Used internally by the package
        controller: _storyController,
        // view: _StoryPageLayout(feature: feature), // Our custom page UI
        duration: const Duration(seconds: 10),
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
      body: StoryView(
        storyItems: _storyItems,
        controller: _storyController,
        onComplete: () => Navigator.of(context).pop(),
        onVerticalSwipeComplete: (direction) {
          if (direction == Direction.down) {
            Navigator.of(context).pop();
          }
        },
        progressPosition: ProgressPosition.top,
        repeat: false,
        inline: false,
      ),
    );
  }
}

// NEW WIDGET FOR THE LAYOUT OF A SINGLE STORY PAGE
class _StoryPageLayout extends StatelessWidget {
  final SafetyFeature feature;

  const _StoryPageLayout({Key? key, required this.feature}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The top progress bars are handled by the StoryView widget automatically.
            // We can add a close button if needed.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                  color: Colors.black,
                )
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: Image.asset(
                feature.popupImagePath,
                height: 200,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              feature.popupTitle,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                decoration:
                    TextDecoration.none, // To override any default styles
              ),
            ),
            const SizedBox(height: 16),
            Text(
              feature.popupDescription,
              style: TextStyle(
                color: Colors.grey[850],
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
