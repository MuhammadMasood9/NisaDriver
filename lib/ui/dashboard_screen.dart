import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<DashBoardController>(
      init: DashBoardController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color.fromARGB(0, 255, 228, 239),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            foregroundColor: const Color.fromARGB(255, 255, 255, 255),
            centerTitle: true,
            surfaceTintColor: Colors.white,
            title: Text(
              controller.selectedDrawerIndex.value == 0
                  ? 'Driver Dashboard'.tr
                  : controller.drawerItems[controller.selectedDrawerIndex.value]
                      .title.tr,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            leading: Builder(
              builder: (context) {
                return InkWell(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 10, right: 20, top: 20, bottom: 20),
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
    final controllerDashBoard = Get.put(DashBoardController());

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Information'.tr),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'To start earning with GoRide you need to fill in your personal information'
                        .tr),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('No'.tr),
              onPressed: () {
                Get.back();
              },
            ),
            TextButton(
              child: Text('Yes'.tr),
              onPressed: () {
                if (type == "document") {
                  controllerDashBoard.onSelectItem(7);
                } else {
                  controllerDashBoard.onSelectItem(8);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget buildAppDrawer(BuildContext context, DashBoardController controller) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    List<DrawerItem> drawerItems = [];
    if (Constant.isSubscriptionModelApplied == true) {
      drawerItems = [
        DrawerItem('City'.tr, "assets/icons/ic_city.svg"),
        DrawerItem('OutStation'.tr, "assets/icons/ic_intercity.svg"),
        DrawerItem('Freight'.tr, "assets/icons/ic_freight.svg"),
        DrawerItem('My Wallet'.tr, "assets/icons/ic_wallet.svg"),
        DrawerItem('Bank Details'.tr, "assets/icons/ic_profile.svg"),
        DrawerItem('Inbox'.tr, "assets/icons/ic_inbox.svg"),
        DrawerItem('Profile'.tr, "assets/icons/ic_profile.svg"),
        DrawerItem('Online Registration'.tr, "assets/icons/ic_document.svg"),
        DrawerItem('Vehicle Information'.tr, "assets/icons/ic_city.svg"),
        DrawerItem('Settings'.tr, "assets/icons/ic_settings.svg"),
        DrawerItem('Subscription'.tr, "assets/icons/ic_subscription.svg"),
        DrawerItem('Subscription History'.tr,
            "assets/icons/ic_subscription_history.svg"),
        DrawerItem('Log out'.tr, "assets/icons/ic_logout.svg"),
      ];
    } else {
      drawerItems = [
        DrawerItem('City'.tr, "assets/icons/ic_city.svg"),
        DrawerItem('OutStation'.tr, "assets/icons/ic_intercity.svg"),
        DrawerItem('Freight'.tr, "assets/icons/ic_freight.svg"),
        DrawerItem('My Wallet'.tr, "assets/icons/ic_wallet.svg"),
        DrawerItem('Bank Details'.tr, "assets/icons/ic_profile.svg"),
        DrawerItem('Inbox'.tr, "assets/icons/ic_inbox.svg"),
        DrawerItem('Profile'.tr, "assets/icons/ic_profile.svg"),
        DrawerItem('Online Registration'.tr, "assets/icons/ic_document.svg"),
        DrawerItem('Vehicle Information'.tr, "assets/icons/ic_city.svg"),
        DrawerItem('Settings'.tr, "assets/icons/ic_settings.svg"),
        DrawerItem('Subscription History'.tr,
            "assets/icons/ic_subscription_history.svg"),
        DrawerItem('Log out'.tr, "assets/icons/ic_logout.svg"),
      ];
    }
    var drawerOptions = <Widget>[];
    for (var i = 0; i < drawerItems.length; i++) {
      var d = drawerItems[i];
      drawerOptions.add(InkWell(
        onTap: () {
          controller.onSelectItem(i);
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: i == controller.selectedDrawerIndex.value
                  ? AppColors.primary
                  : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SvgPicture.asset(
                  d.icon,
                  width: 20,
                  color: i == controller.selectedDrawerIndex.value
                      ? themeChange.getThem()
                          ? Colors.black
                          : Colors.white
                      : themeChange.getThem()
                          ? Colors.white
                          : AppColors.drawerIcon,
                ),
                const SizedBox(width: 20),
                Text(
                  d.title,
                  style: GoogleFonts.poppins(
                    color: i == controller.selectedDrawerIndex.value
                        ? themeChange.getThem()
                            ? Colors.black
                            : Colors.white
                        : themeChange.getThem()
                            ? Colors.white
                            : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    }
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: FutureBuilder<DriverUserModel?>(
              future: FireStoreUtils.getDriverProfile(
                  FireStoreUtils.getCurrentUid()),
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return Constant.loader(context);
                  case ConnectionState.done:
                    if (snapshot.hasError) {
                      return Text(snapshot.error.toString());
                    } else {
                      DriverUserModel driverModel = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: CachedNetworkImage(
                              height: Responsive.width(20, context),
                              width: Responsive.width(20, context),
                              imageUrl: driverModel.profilePic.toString(),
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Constant.loader(context),
                              errorWidget: (context, url, error) =>
                                  Image.network(Constant.userPlaceHolder),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              driverModel.fullName.toString(),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              driverModel.email.toString(),
                              style: GoogleFonts.poppins(),
                            ),
                          ),
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
