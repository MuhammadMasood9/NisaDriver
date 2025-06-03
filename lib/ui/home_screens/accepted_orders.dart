import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/accepted_orders_controller.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
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
      // Check if timer start time exists in Firestore
      DocumentSnapshot timerDoc = await FirebaseFirestore.instance
          .collection('driver_timers')
          .doc(timerKey)
          .get();

      if (timerDoc.exists) {
        // Timer already exists, calculate remaining time
        Map<String, dynamic> timerData =
            timerDoc.data() as Map<String, dynamic>;
        Timestamp startTimestamp = timerData['startTime'];
        _timerStartTime = startTimestamp.toDate();

        int elapsedSeconds =
            DateTime.now().difference(_timerStartTime!).inSeconds;
        int remaining = TIMER_DURATION - elapsedSeconds;

        if (remaining <= 0) {
          // Timer already expired
          _isExpired.value = true;
          await _handleExpiredTimer();
          return;
        } else {
          _remainingSeconds.value = remaining;
        }
      } else {
        // Create new timer
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
      // Fallback to local timer
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
      // Clean up timer document
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
      // Clean up timer document
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
                    // Timer indicator
                    TimerIndicator(remainingSeconds: _remainingSeconds),
                    // Order details
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
                                const SizedBox(width: 10),
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
