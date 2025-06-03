import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<DashBoardController>(
      init: DashBoardController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color.fromARGB(0, 255, 255, 255),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.white,
            centerTitle: true,
            surfaceTintColor: Colors.white,
            title: Text(
              controller.selectedDrawerIndex.value == 0
                  ? 'Driver Dashboard'.tr
                  : controller.drawerItems[controller.selectedDrawerIndex.value]
                      .title.tr,
              style: AppTypography.appBar(context),
            ),
            leading: Builder(
              builder: (context) {
                return InkWell(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 20),
                    child: SvgPicture.asset(
                      'assets/icons/ic_humber.svg',
                      color: Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
          drawer: buildAppDrawer(context, controller),
          body: WillPopScope(
            onWillPop: controller.onWillPop,
            child: controller
                .getDrawerItemWidget(controller.selectedDrawerIndex.value),
          ),
        );
      },
    );
  }

  Future<void> _showAlertDialog(BuildContext context, String type) async {
    final controllerDashBoard = Get.find<DashBoardController>();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Information'.tr),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text(
                    'To start earning with NisaRide you need to fill in your personal information'
                        .tr),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('No'.tr),
              onPressed: () => Get.back(),
            ),
            TextButton(
              child: Text('Yes'.tr),
              onPressed: () {
                if (type == "document") {
                  controllerDashBoard.onSelectItem(6); // Online Registration
                } else {
                  controllerDashBoard.onSelectItem(7); // Vehicle Information
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget buildAppDrawer(BuildContext context, DashBoardController controller) {
    var drawerOptions = <Widget>[];
    for (var i = 0; i < controller.drawerItems.length; i++) {
      var d = controller.drawerItems[i];
      drawerOptions.add(InkWell(
        onTap: () => controller.onSelectItem(i),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Container(
            decoration: BoxDecoration(
              color: i == controller.selectedDrawerIndex.value
                  ? AppColors.primary
                  : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SvgPicture.asset(
                  d.icon,
                  width: 16,
                  color: i == controller.selectedDrawerIndex.value
                      ? Colors.white
                      : AppColors.grey500,
                ),
                const SizedBox(width: 15),
                Text(
                  d.title,
                  style: AppTypography.sideBar(context).copyWith(
                    color: i == controller.selectedDrawerIndex.value
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    }

    return Drawer(
      backgroundColor: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: FutureBuilder<DriverUserModel?>(
              future: FireStoreUtils.getCurrentUid() != null
                  ? FireStoreUtils.getDriverProfile(
                      FireStoreUtils.getCurrentUid()!)
                  : Future.value(null),
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return Constant.loader(context);
                  case ConnectionState.done:
                    if (snapshot.hasError) {
                      return Text(snapshot.error.toString());
                    } else {
                      DriverUserModel driverModel = snapshot.data!;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 10,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              height: Responsive.width(24, context),
                              width: Responsive.width(24, context),
                              imageUrl: driverModel.profilePic.toString(),
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Constant.loader(context),
                              errorWidget: (context, url, error) =>
                                  Image.network(Constant.userPlaceHolder),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  driverModel.fullName.toString(),
                                  style: AppTypography.boldHeaders(context),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  driverModel.email.toString(),
                                  style: AppTypography.caption(context),
                                ),
                              ),
                              Row(
                                spacing: 5,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 15,
                                    color: AppColors.ratingColour,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      driverModel.reviewsSum.toString(),
                                      style: AppTypography.boldLabel(context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        ],
                      );
                    }
                  default:
                    return Text('Error'.tr);
                }
              },
            ),
          ),
          Column(children: drawerOptions),
        ],
      ),
    );
  }
}
