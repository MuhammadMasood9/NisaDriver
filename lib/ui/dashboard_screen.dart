import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<DashBoardController>(
      init: DashBoardController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.background,
          // The AppBar is now a primary part of the Scaffold
          appBar: AppBar(
            elevation: 0.5,
            shadowColor: AppColors.grey50,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: Text(
              // Dynamic title based on the selected screen
              controller.selectedDrawerIndex.value == 0
                  ? 'Driver Dashboard'.tr
                  : controller.drawerItems[controller.selectedDrawerIndex.value]
                      .title.tr,
              style: AppTypography.appBar(context),
            ),
            centerTitle: true,
            // The leading icon now opens the drawer
            leading: Builder(
              builder: (context) {
                return InkWell(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: SvgPicture.asset(
                      'assets/icons/ic_humber.svg',
                      colorFilter: const ColorFilter.mode(
                        AppColors.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                );
              },
            ),
            // The Online/Offline switch is moved here for constant visibility
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 5.0),
                // Center the switch vertically in the AppBar
                child: Center(
                  // Use Transform.scale to adjust the size of the Switch
                  child: Transform.scale(
                    // Values < 1.0 make it smaller, > 1.0 make it larger.
                    scale: 0.8,
                    child: Obx(() => Switch(
                          value: controller.isOnline.value,
                          onChanged: (value) {
                            controller.toggleOnlineStatus(value);
                          },
                          activeColor: AppColors.primary,
                          inactiveThumbColor: AppColors.grey500,
                        )),
                  ),
                ),
              )
            ],
          ),
          drawer: _buildSimpleDrawer(context, controller),
          body: WillPopScope(
            onWillPop: controller.onWillPop,
            child: controller
                .getDrawerItemWidget(controller.selectedDrawerIndex.value),
          ),
        );
      },
    );
  }

  /// Builds the main navigation drawer with the modern style.
  Widget _buildSimpleDrawer(
      BuildContext context, DashBoardController controller) {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      width: Responsive.width(90, Get.context!),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildUserProfile(context, controller),
            const SizedBox(height: 5),
            Divider(
              color: AppColors.grey200,
            ),
            const SizedBox(height: 5),
            Expanded(
              child: _buildMenuItems(context, controller),
            ),
            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }

  /// Builds the user profile section in the drawer header.
  /// It includes a FutureBuilder to fetch user data and shows loading/error states.
  Widget _buildUserProfile(
      BuildContext context, DashBoardController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: FutureBuilder<DriverUserModel?>(
        future: FireStoreUtils.getCurrentUid() != null
            ? FireStoreUtils.getDriverProfile(FireStoreUtils.getCurrentUid()!)
            : Future.value(null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildProfileSkeleton();
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _buildProfileError();
          }

          DriverUserModel driverModel = snapshot.data!;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProfileImage(driverModel.profilePic.toString()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverModel.fullName.toString(),
                      style: AppTypography.appTitle(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      driverModel.email.toString(),
                      style: AppTypography.caption(context).copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: AppColors.ratingColour,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          driverModel.reviewsSum.toString(),
                          style: AppTypography.smBoldLabel(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              // The switch has been removed from here to avoid duplication.
            ],
          );
        },
      ),
    );
  }

  /// Builds the circular profile image with a placeholder and error widget.
  Widget _buildProfileImage(String imageUrl) {
    return SizedBox(
      width: 50,
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[100],
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.network(Constant.userPlaceHolder),
            ),
          ),
        ),
      ),
    );
  }

  /// A skeleton loader widget for the profile section.
  Widget _buildProfileSkeleton() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 18,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 8),
              Container(
                width: 150,
                height: 14,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// An error widget for the profile section.
  Widget _buildProfileError() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.error_outline,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Could not load profile'.tr,
            style: AppTypography.caption(Get.context!).copyWith(
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the list of tappable menu items for the drawer.
  Widget _buildMenuItems(BuildContext context, DashBoardController controller) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: controller.drawerItems.length,
      itemBuilder: (context, index) {
        final item = controller.drawerItems[index];
        final isSelected = index == controller.selectedDrawerIndex.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => controller.onSelectItem(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.09)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      item.icon,
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        isSelected ? AppColors.primary : Colors.grey.shade600,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item.title.tr,
                        style: AppTypography.sideBar(context).copyWith(
                          color:
                              isSelected ? AppColors.primary : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
