import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dash/flutter_dash.dart';

class LocationView extends StatelessWidget {
  final String? sourceLocation;
  final String? destinationLocation;

  const LocationView({
    super.key,
    this.sourceLocation,
    this.destinationLocation,
  });

  @override
  Widget build(BuildContext context) {
    const double iconSize = 18.0;
    const double indentSpace = 10.0;

    return Column(
      mainAxisSize: MainAxisSize.min, // Use minimum vertical space
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Source Location Row
        Row(
          children: [
            Image.asset(
              'assets/pickup.png', // Correct icon for source/pickup
              width: iconSize,
            ),
            const SizedBox(width: indentSpace),
            Expanded(
              child: Text(
                sourceLocation ?? 'Not available',
                style: AppTypography.label(context),
                maxLines: 1, // Ensure single line
                overflow: TextOverflow.ellipsis, // Add '...' for long text
              ),
            ),
          ],
        ),

        // 2. Vertical Dotted Line
        Padding(
          // Indent the dash to align with the center of the icons
          padding: EdgeInsets.only(
            left: iconSize / 2 - 1, // Center the dash
            top: 4,
            bottom: 4,
          ),
          child: const Dash(
            direction: Axis.vertical,
            length: 12, // A fixed length often looks better
            dashLength: 5,
            dashThickness: 1,
            dashColor: AppColors.dottedDivider,
          ),
        ),

        // 3. Destination Location Row
        Row(
          children: [
            Image.asset(
              'assets/dropoff.png', // Correct icon for destination/dropoff
              width: iconSize,
            ),
            const SizedBox(width: indentSpace),
            Expanded(
              child: Text(
                destinationLocation ?? 'Not available',
                style: AppTypography.label(context),
                maxLines: 1, // Ensure single line
                overflow: TextOverflow.ellipsis, // Add '...' for long text
              ),
            ),
          ],
        ),
      ],
    );
  }
}
