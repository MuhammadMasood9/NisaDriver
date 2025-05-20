import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/accepted_orders_controller.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
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
    final themeChange = Provider.of<DarkThemeProvider>(context);

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
                  themeChange: themeChange,
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
  final DarkThemeProvider themeChange;
  final AcceptedOrdersController controller;

  const OrderItemWithTimer({
    Key? key,
    required this.orderModel,
    required this.themeChange,
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

  @override
  void initState() {
    super.initState();
    _loadDriverData();
    _startTimer();
  }

  Future<void> _loadDriverData() async {
    _driverIdAcceptReject = await FireStoreUtils.getAcceptedOrders(
      widget.orderModel.id.toString(),
      FireStoreUtils.getCurrentUid(),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds.value = 30;
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
    String driverId = FireStoreUtils.getCurrentUid();
    try {
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
                  color: widget.themeChange.getThem()
                      ? AppColors.darkContainerBackground
                      : AppColors.containerBackground,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: widget.themeChange.getThem()
                        ? AppColors.darkContainerBorder
                        : AppColors.containerBorder,
                    width: 0.5,
                  ),
                  boxShadow: widget.themeChange.getThem()
                      ? null
                      : [
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
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    _timer?.cancel();
                                    _isExpired.value = true;
                                    _handleExpiredTimer();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text('Cancel'.tr),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        decoration: BoxDecoration(
          color: widget.themeChange.getThem()
              ? AppColors.darkContainerBackground
              : AppColors.containerBackground,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(
            color: widget.themeChange.getThem()
                ? AppColors.darkContainerBorder
                : AppColors.containerBorder,
            width: 0.5,
          ),
          boxShadow: widget.themeChange.getThem()
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
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
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                Constant.amountShow(
                    amount: _driverIdAcceptReject!.offerAmount.toString()),
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
