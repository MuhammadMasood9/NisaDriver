import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/home_screens/order_map_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class NewOrderScreen extends StatelessWidget {
  const NewOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX<HomeController>(
      init: HomeController(),
      dispose: (state) {
        FireStoreUtils().closeStream();
      },
      builder: (controller) {
        if (controller.isLoading.value) {
          return Constant.loader(context);
        }

        // Main screen with a scrollable view for both accepted and new orders
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Section 1: Accepted Rides with Timer ---
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 12.0),
                child: Text(
                  "Accepted Rides".tr,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 18),
                ),
              ),
              _buildAcceptedOrdersSection(),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(thickness: 1.5),
              ),

              // --- Section 2: New Ride Requests ---
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Text(
                  "New Ride Requests".tr,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 18),
                ),
              ),
              _buildNewOrdersSection(context, controller),
            ],
          ),
        );
      },
    );
  }

  /// Builds the list of rides that the driver has accepted and are awaiting confirmation.
  Widget _buildAcceptedOrdersSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(CollectionName.orders)
          .where('acceptedDriverId',
              arrayContains: FireStoreUtils.getCurrentUid())
          .snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Something went wrong'.tr));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Constant.loader(context);
        }
        if (snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("No accepted rides found".tr),
            ),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          scrollDirection: Axis.vertical,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            OrderModel orderModel = OrderModel.fromJson(
                snapshot.data!.docs[index].data() as Map<String, dynamic>);
            return OrderItemWithTimer(
              orderModel: orderModel,
            );
          },
        );
      },
    );
  }

  /// Builds the list of new ride requests available to the driver,
  /// only if the driver is online and verified.
  Widget _buildNewOrdersSection(
      BuildContext context, HomeController controller) {
    // Check if driver is offline
    if (controller.driverModel.value.isOnline == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("You are offline. Go online to see new ride requests.".tr,
              textAlign: TextAlign.center),
        ),
      );
    }
    // Check if documents are verified
    if (controller.driverModel.value.documentVerification == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Your documents are not verified. Please complete document verification to receive ride orders."
                .tr,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // If online and verified, show the stream of new orders
    return StreamBuilder<List<OrderModel>>(
      stream: FireStoreUtils().getOrders(
          controller.driverModel.value,
          Constant.currentLocation?.latitude,
          Constant.currentLocation?.longitude),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Constant.loader(context);
        }
        if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("No new rides found nearby".tr),
            ),
          );
        } else {
          return ListView.builder(
            itemCount: snapshot.data!.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              OrderModel orderModel = snapshot.data![index];
              String amount;
              if (Constant.distanceType == "Km") {
                amount = Constant.amountCalculate(
                        orderModel.service!.kmCharge.toString(),
                        orderModel.distance.toString())
                    .toStringAsFixed(Constant.currencyModel!.decimalDigits!);
              } else {
                amount = Constant.amountCalculate(
                        orderModel.service!.kmCharge.toString(),
                        orderModel.distance.toString())
                    .toStringAsFixed(Constant.currencyModel!.decimalDigits!);
              }
              return InkWell(
                onTap: () {
                  Get.to(const OrderMapScreen(),
                          arguments: {"orderModel": orderModel.id.toString()})!
                      .then((value) {
                    if (value != null && value == true) {
                      controller.selectedIndex.value = 1;
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.containerBackground,
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      child: Column(
                        children: [
                          UserView(
                            userId: orderModel.userId,
                            amount: orderModel.offerRate,
                            distance: orderModel.distance,
                            distanceType: orderModel.distanceType,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 5),
                            child: Divider(),
                          ),
                          LocationView(
                            sourceLocation:
                                orderModel.sourceLocationName.toString(),
                            destinationLocation:
                                orderModel.destinationLocationName.toString(),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: Container(
                              width: Responsive.width(100, context),
                              decoration: BoxDecoration(
                                  color: AppColors.gray,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(10))),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                child: Center(
                                  child: Text(
                                    'Recommended Price is ${Constant.amountShow(amount: amount)}. Approx distance ${double.parse(orderModel.distance.toString()).toStringAsFixed(Constant.currencyModel!.decimalDigits!)} ${Constant.distanceType}',
                                    style: AppTypography.smBoldLabel(context),
                                  ),
                                ),
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
      },
    );
  }
}

// --- Widgets for the Accepted Order Item with Timer ---

class OrderItemWithTimer extends StatefulWidget {
  final OrderModel orderModel;

  const OrderItemWithTimer({
    Key? key,
    required this.orderModel,
  }) : super(key: key);

  @override
  State<OrderItemWithTimer> createState() => _OrderItemWithTimerState();
}

class _OrderItemWithTimerState extends State<OrderItemWithTimer> {
  final RxInt _remainingSeconds = 30.obs;
  final RxBool _isExpired = false.obs;
  Timer? _timer;
  DriverIdAcceptReject? _driverIdAcceptReject;
  DateTime? _timerStartTime;
  static const int TIMER_DURATION = 30; // 30 seconds

  @override
  void initState() {
    super.initState();
    _loadDriverData();
    _initializeTimer();
  }

  Future<void> _loadDriverData() async {
    String? currentUid = FireStoreUtils.getCurrentUid();
    if (currentUid != null) {
      _driverIdAcceptReject = await FireStoreUtils.getAcceptedOrders(
        widget.orderModel.id.toString(),
        currentUid,
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _initializeTimer() async {
    String? driverId = FireStoreUtils.getCurrentUid();
    if (driverId == null) return;
    String timerKey = '${widget.orderModel.id}_${driverId}_timer_start';

    try {
      DocumentSnapshot timerDoc = await FirebaseFirestore.instance
          .collection('driver_timers')
          .doc(timerKey)
          .get();

      if (timerDoc.exists) {
        Map<String, dynamic> timerData =
            timerDoc.data() as Map<String, dynamic>;
        Timestamp startTimestamp = timerData['startTime'];
        _timerStartTime = startTimestamp.toDate();

        int elapsedSeconds =
            DateTime.now().difference(_timerStartTime!).inSeconds;
        int remaining = TIMER_DURATION - elapsedSeconds;

        if (remaining <= 0) {
          _isExpired.value = true;
          await _handleExpiredTimer();
          return;
        } else {
          _remainingSeconds.value = remaining;
        }
      } else {
        _timerStartTime = DateTime.now();
        await FirebaseFirestore.instance
            .collection('driver_timers')
            .doc(timerKey)
            .set({
          'startTime': Timestamp.fromDate(_timerStartTime!),
          'orderId': widget.orderModel.id,
          'driverId': driverId,
          'duration': TIMER_DURATION,
        });
        _remainingSeconds.value = TIMER_DURATION;
      }

      _startTimer();
    } catch (e) {
      print('Error initializing timer: $e');
      _remainingSeconds.value = TIMER_DURATION;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds.value > 0) {
        _remainingSeconds.value--;
      } else {
        _timer?.cancel();
        _isExpired.value = true;
        _handleExpiredTimer();
      }
    });
  }

  Future<void> _handleExpiredTimer() async {
    String? driverId = FireStoreUtils.getCurrentUid();
    if (driverId == null) return;
    String timerKey = '${widget.orderModel.id}_${driverId}_timer_start';

    try {
      await FirebaseFirestore.instance
          .collection('driver_timers')
          .doc(timerKey)
          .delete();

      DocumentReference orderRef = FirebaseFirestore.instance
          .collection(CollectionName.orders)
          .doc(widget.orderModel.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot orderSnapshot = await transaction.get(orderRef);
        if (orderSnapshot.exists) {
          Map<String, dynamic> orderData =
              orderSnapshot.data() as Map<String, dynamic>;
          List<dynamic> rejectedDriverIds =
              (orderData['rejectedDriverId'] ?? []).cast<dynamic>();
          List<dynamic> acceptedDriverIds =
              (orderData['acceptedDriverId'] ?? []).cast<dynamic>();

          if (!rejectedDriverIds.contains(driverId)) {
            rejectedDriverIds.add(driverId);
          }
          acceptedDriverIds.remove(driverId);

          transaction.update(orderRef, {
            'rejectedDriverId': rejectedDriverIds,
            'acceptedDriverId': acceptedDriverIds,
          });
        }
      });

      Get.snackbar(
        'Time Expired'.tr,
        'Your acceptance for this ride has expired'.tr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Error updating order after timer expired: $e');
    }
  }

  Future<void> _cancelTimer() async {
    String? driverId = FireStoreUtils.getCurrentUid();
    if (driverId == null) return;
    String timerKey = '${widget.orderModel.id}_${driverId}_timer_start';

    try {
      await FirebaseFirestore.instance
          .collection('driver_timers')
          .doc(timerKey)
          .delete();
    } catch (e) {
      print('Error cleaning up timer: $e');
    }

    _timer?.cancel();
    _isExpired.value = true;
    _handleExpiredTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _isExpired.value
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.containerBackground,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TimerIndicator(remainingSeconds: _remainingSeconds),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 10),
                      child: Column(
                        children: [
                          UserView(
                            userId: widget.orderModel.userId,
                            amount: widget.orderModel.offerRate,
                            distance: widget.orderModel.distance,
                            distanceType: widget.orderModel.distanceType,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 5),
                            child: Divider(),
                          ),
                          _buildOfferRate(),
                          const SizedBox(height: 10),
                          LocationView(
                            sourceLocation:
                                widget.orderModel.sourceLocationName.toString(),
                            destinationLocation: widget
                                .orderModel.destinationLocationName
                                .toString(),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _cancelTimer,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(
                                      'Cancel'.tr,
                                      style: AppTypography.boldLabel(context)
                                          .copyWith(
                                              color: AppColors.background),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOfferRate() {
    if (_driverIdAcceptReject == null) {
      return Constant.loader(context);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.containerBackground,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.09),
              blurRadius: 5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Offer Rate".tr,
                  style: AppTypography.boldLabel(context),
                ),
              ),
              Text(
                Constant.amountShow(
                    amount: _driverIdAcceptReject!.offerAmount.toString()),
                style: AppTypography.boldLabel(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TimerIndicator extends StatelessWidget {
  final RxInt remainingSeconds;

  const TimerIndicator({Key? key, required this.remainingSeconds})
      : super(key: key);

  Color _getTimerColor() {
    if (remainingSeconds.value > 20) {
      return Colors.green;
    } else if (remainingSeconds.value > 10) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _getTimerColor(),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: Text(
              'Expires in ${remainingSeconds.value} seconds'.tr,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
