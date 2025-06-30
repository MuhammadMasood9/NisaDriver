import 'package:cloud_firestore/cloud_firestore.dart' as cloud_firestore;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
// import 'package:driver/model/driver_model.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/*
  ✅ INTEGRATION STEPS (If not already done):

  1. Add this method to your `lib/utils/fire_store_utils.dart` file:
  --------------------------------------------------------------------------------
    static Future<List<OrderModel>> getScheduledOrders() async {
      List<OrderModel> rideList = [];
      try {
        QuerySnapshot<Map<String, dynamic>> rideSnapshot = await firestore
            .collection(CollectionName.orders)
            .where('isScheduledRide', isEqualTo: true)
            .where('status', isEqualTo: 'scheduled')
            .orderBy('createdDate', descending: true)
            .get();

        for (var document in rideSnapshot.docs) {
          OrderModel ride = OrderModel.fromJson(document.data());
          rideList.add(ride);
        }
      } catch (e, s) {
        print('-----------GET-SCHEDULED-ORDERS-ERROR-----------');
        print(e);
        print(s);
      }
      return rideList;
    }
  --------------------------------------------------------------------------------

  2. In your `lib/controller/home_controller.dart`, add this screen to your `widgetOptions`.
  3. In your `lib/ui/home_screen.dart`, add a new navigation item for "Scheduled" rides.
*/

/// Controller for fetching and managing scheduled ride data.
class ScheduledOrderController extends GetxController {
  RxBool isLoading = true.obs;
  RxList<OrderModel> scheduledOrdersList = <OrderModel>[].obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
  }

  /// Fetches both scheduled orders and the current driver's data in parallel.
  Future<void> fetchInitialData() async {
    isLoading.value = true;
    try {
      await Future.wait([
        fetchScheduledOrders(),
        fetchDriverData(),
      ]);
    } catch (e) {
      print("Error fetching initial data: $e");
      Get.snackbar("Error".tr, "Failed to load data.".tr);
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetches the current driver's data from Firestore.
  Future<void> fetchDriverData() async {
    final driver = await FireStoreUtils.getDriverProfile(FireStoreUtils.getCurrentUid() ?? '');
    if (driver != null) {
      driverModel.value = driver;
    }
  }

  /// Fetches scheduled orders from Firestore and filters out any rejected by the current driver.
  Future<void> fetchScheduledOrders() async {
    try {
      List<OrderModel> orders = await FireStoreUtils.getScheduledOrders();
      String currentDriverId = FireStoreUtils.getCurrentUid() ?? '';

      // Filter out orders that this driver has already rejected
      scheduledOrdersList.value = orders.where((order) {
        final rejectedIds = order.rejectedDriverId ?? [];
        return !rejectedIds.contains(currentDriverId);
      }).toList();
    } catch (e) {
      print("Error fetching scheduled orders: $e");
      Get.snackbar(
        "Error".tr,
        "Failed to load scheduled rides.".tr,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  /// Handles the logic for a driver accepting a scheduled ride.
  Future<void> acceptRide(OrderModel order) async {
    // 1. Check if driver's wallet has sufficient funds
    if (double.parse(driverModel.value.walletAmount.toString()) <
        double.parse(Constant.minimumDepositToRideAccept ?? '0.0')) {
      ShowToastDialog.showToast(
        "You need at least ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept)} in your wallet to accept this order.".tr,
      );
      return;
    }

    ShowToastDialog.showLoader("Accepting Ride...".tr);

    try {
      String driverId = FireStoreUtils.getCurrentUid() ?? '';

      // 2. Prepare the data to update in Firestore
      Map<String, dynamic> updatedData = {
        'status': Constant.rideActive, // Update status to 'accepted'
        'driverId': driverId,
        'driver': driverModel.value.toJson(), // Attach driver's details
      };

      // 3. Update the order document
      await FireStoreUtils.fireStore
          .collection(CollectionName.orders)
          .doc(order.id)
          .update(updatedData);

      // 4. Notify the customer
      var customer = await FireStoreUtils.getCustomer(order.userId.toString());
      if (customer != null && customer.fcmToken != null) {
        await SendNotification.sendOneNotification(
          token: customer.fcmToken!,
          title: 'Ride Secured!'.tr,
          body: 'A driver has accepted your scheduled ride.'.tr,
          payload: {'orderId': order.id},
        );
      }

      // 5. Update the local list to remove the accepted ride from the screen instantly
      scheduledOrdersList.remove(order);
      scheduledOrdersList.refresh();

      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Ride Accepted! It's now in your 'Accepted' list.".tr);

    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Failed to accept ride: $e".tr);
      if (kDebugMode) {
        print("Error accepting scheduled ride: $e");
      }
    }
  }
}

/// A screen to display a list of available scheduled rides.
class ScheduledOrderScreen extends StatelessWidget {
  const ScheduledOrderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<ScheduledOrderController>(
      init: ScheduledOrderController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: controller.isLoading.value
              ? Constant.loader(context)
              : RefreshIndicator(
                  onRefresh: () => controller.fetchInitialData(),
                  color: AppColors.primary,
                  child: Column(
                    children: [
                      _buildHeader(context),
                      Expanded(
                        child: controller.scheduledOrdersList.isEmpty
                            ? _buildEmptyState(context, controller)
                            : ListView.builder(
                                itemCount: controller.scheduledOrdersList.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                itemBuilder: (context, index) {
                                  OrderModel order = controller.scheduledOrdersList[index];
                                  return _buildScheduledRideCard(context, order, controller);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            "Scheduled Rides".tr,
            style: AppTypography.headers(context).copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ScheduledOrderController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: constraints.maxHeight,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                Text(
                  "No Scheduled Rides Available".tr,
                  style: AppTypography.headers(context).copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    "Check back later for new scheduled ride opportunities.".tr,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(context).copyWith(color: Colors.grey.shade500),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => controller.fetchInitialData(),
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text("Refresh".tr),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduledRideCard(BuildContext context, OrderModel order, ScheduledOrderController controller) {
    final rideDate = order.createdDate?.toDate();
    final formattedDate = rideDate != null ? DateFormat('E, d MMM yyyy').format(rideDate) : 'N/A';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Date and Fare
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(formattedDate, style: AppTypography.label(context).copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(
                  Constant.amountShow(amount: order.finalRate ?? '0'),
                  style: AppTypography.headers(context).copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),

            // Location Info
            _buildLocationRow(
              icon: Icons.my_location,
              color: Colors.green.shade600,
              title: "Pickup".tr,
              subtitle: order.sourceLocationName ?? 'Not specified',
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Container(
                height: 20,
                width: 1.5,
                color: Colors.grey.shade300,
              ),
            ),
            _buildLocationRow(
              icon: Icons.location_on,
              color: Colors.red.shade600,
              title: "Drop-off".tr,
              subtitle: order.destinationLocationName ?? 'Not specified',
            ),
            const SizedBox(height: 20),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 20),
                onPressed: () => controller.acceptRide(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                label: Text("Accept Ride".tr, style: AppTypography.buttonlight(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.caption(Get.context!).copyWith(color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.headers(Get.context!),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}