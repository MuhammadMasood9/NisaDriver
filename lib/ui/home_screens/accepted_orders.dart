import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/accepted_orders_controller.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/home_screens/order_map_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AcceptedOrders extends StatelessWidget {
  const AcceptedOrders({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AcceptedOrdersController>(
      init: AcceptedOrdersController(),
      dispose: (state) {
        FireStoreUtils().closeStream();
      },
      builder: (controller) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(CollectionName.orders)
              .where('acceptedDriverId',
                  arrayContains: FireStoreUtils.getCurrentUid())
              .snapshots(),
          builder:
              (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Something went wrong'.tr));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Constant.loader(context);
            }
            if (snapshot.data!.docs.isEmpty) {
              return Center(child: Text("No accepted ride found".tr));
            }
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                OrderModel orderModel = OrderModel.fromJson(
                    snapshot.data!.docs[index].data() as Map<String, dynamic>);
                return OrderItemWithTimer(
                  orderModel: orderModel,
                  controller: controller,
                );
              },
            );
          },
        );
      },
    );
  }
}
// ~~~ Keep your existing imports and the 'AcceptedOrders' widget as they are ~~~
// ... (imports from your original code)
// ... (AcceptedOrders class from your original code)


// REPLACE the existing OrderItemWithTimer and _OrderItemWithTimerState
// with the following updated code.

class OrderItemWithTimer extends StatefulWidget {
  final OrderModel orderModel;
  final AcceptedOrdersController controller;

  const OrderItemWithTimer({
    Key? key,
    required this.orderModel,
    required this.controller,
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

      if (Get.isSnackbarOpen == false) {
        Get.snackbar(
          'Time Expired'.tr,
          'Your acceptance for this ride has expired'.tr,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
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
    if (!_isExpired.value) {
      _isExpired.value = true; // Prevents the widget from being interactable
      _handleExpiredTimer(); // Reuse logic to remove driver from accepted list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _isExpired.value
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: InkWell(
                onTap: () {
                  // Pause timer to prevent expiration while on the map screen
                  _timer?.cancel();
                  Get.to(const OrderMapScreen(),
                          arguments: {"orderModel": widget.orderModel.id.toString()})!
                      .then((value) {
                    // This code runs when returning from OrderMapScreen

                    // Resume timer if the widget is still active
                    if (mounted && !_isExpired.value) {
                      if (_timerStartTime != null) {
                        final elapsed = DateTime.now().difference(_timerStartTime!).inSeconds;
                        final remaining = TIMER_DURATION - elapsed;
                        if (remaining > 0) {
                          _remainingSeconds.value = remaining;
                          _startTimer();
                        } else {
                          _isExpired.value = true;
                          _handleExpiredTimer();
                        }
                      } else {
                        _startTimer(); // Fallback
                      }
                    }

                    if (value != null && value == true) {
                      // widget.controller.selectedIndex.value = 1;
                    }
                  });
                },
                borderRadius: const BorderRadius.all(Radius.circular(15)),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.containerBackground,
                    borderRadius: const BorderRadius.all(Radius.circular(15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TimerIndicator(remainingSeconds: _remainingSeconds),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // UserView(
                            //   userId: widget.orderModel.userId,
                            // ),
                            const SizedBox(height: 12),
                            LocationView(
                              sourceLocation: widget.orderModel.sourceLocationName.toString(),
                              destinationLocation: widget.orderModel.destinationLocationName.toString(),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Divider(thickness: 1),
                            ),
                            _buildInfoRow(),
                            const SizedBox(height: 16),
                            _buildCancelButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow() {
    if (_driverIdAcceptReject == null) {
      return Center(child: Constant.loader(context));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildInfoItem(
          icon: Icons.local_offer_outlined,
          title: "Offer Rate".tr,
          value: Constant.amountShow(
              amount: _driverIdAcceptReject!.offerAmount.toString()),
        ),
        _buildInfoItem(
          icon: Icons.directions_car_filled_outlined,
          title: "Distance".tr,
          value:
              "${widget.orderModel.distance} ${widget.orderModel.distanceType}",
        ),
      ],
    );
  }

  Widget _buildInfoItem(
      {required IconData icon, required String title, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style:
              AppTypography.caption(context).copyWith(color: AppColors.grey200),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              value,
              style: AppTypography.boldLabel(context).copyWith(fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.cancel_outlined),
        onPressed: _cancelTimer,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        label: Text(
          'Cancel Ride'.tr,
          style: AppTypography.boldLabel(context).copyWith(
            color: Colors.white,
            fontSize: 16,
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
      return Colors.orange.shade700;
    } else {
      return Colors.red.shade700;
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
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: Text(
              'Tap card to view on map • Expires in ${remainingSeconds.value}s'.tr,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}