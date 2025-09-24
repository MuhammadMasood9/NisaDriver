import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/active_order_controller.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order/location_lat_lng.dart';
import 'package:driver/model/order/positions.dart';
import 'package:driver/ui/home_screens/active_order_screen.dart';
import 'package:driver/ui/order_screen/order_screen.dart';
import 'package:driver/ui/home_screens/new_orders_screen.dart' as home;
import 'package:driver/ui/scheduled_rides/scheduled_order_screen.dart'
    as scheduled;
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/geoflutterfire/src/geoflutterfire.dart';
import 'package:driver/widget/geoflutterfire/src/models/point.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';

class HomeController extends GetxController {
  RxInt selectedIndex = 0.obs;
  List<Widget> widgetOptions = <Widget>[
    const home.NewOrderScreen(),
    const scheduled.ScheduledOrderScreen(),
    const ActiveOrderScreen(),
    const OrderScreen()
  ];
  DashBoardController dashboardController = Get.put(DashBoardController());
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;
  RxBool isLoading = true.obs;
  void onItemTapped(int index) {
    selectedIndex.value = index;

    // Refresh data when switching to New tab (index 0)
    if (index == 0) {
      try {
        final newOrderController = Get.find<home.NewOrderController>();
        newOrderController.refreshData();
      } catch (e) {
        // Controller might not be initialized yet, which is fine
      }
    }
  }

  @override
  void onInit() {
    // TODO: implement onInit
    getDriver();
    getActiveRide();
    super.onInit();
  }

  getDriver() {
    FireStoreUtils.fireStore
        .collection(CollectionName.driverUsers)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen((event) {
      log("my driver ${event.data()!}");
      if (event.exists) {
        driverModel.value = DriverUserModel.fromJson(event.data()!);
        log("controller driver ${driverModel.value}");
      }
    });
    updateCurrentLocation();
  }

  RxInt isActiveValue = 0.obs;
  StreamSubscription? _activeRideSubscription;

  @override
  void onClose() {
    _activeRideSubscription?.cancel();
    super.onClose();
  }

  getActiveRide() {
    // Cancel existing subscription to prevent multiple listeners
    _activeRideSubscription?.cancel();
    
    _activeRideSubscription = FirebaseFirestore.instance
        .collection(CollectionName.orders)
        .where('driverId', isEqualTo: FireStoreUtils.getCurrentUid())
        .where('status',
            whereIn: [Constant.rideInProgress, Constant.rideActive])
        .snapshots()
        .listen((event) {
          isActiveValue.value = event.size;
          // Removed excessive logging to prevent crashes
          
          // Force refresh of the active order screen if it exists
          try {
            if (Get.isRegistered<ActiveOrderController>()) {
              final activeOrderController = Get.find<ActiveOrderController>();
              activeOrderController.refreshData();
            }
          } catch (e) {
            // Removed excessive logging to prevent crashes
            if (kDebugMode) {
              print("Error refreshing active order controller: $e");
            }
          }
        });
  }

  Location location = Location();

  updateCurrentLocation() async {
    PermissionStatus permissionStatus = await location.hasPermission();
    if (permissionStatus == PermissionStatus.granted) {
      try {
        await location.enableBackgroundMode(enable: true);
      } catch (e) {
        print('Background location permission denied: $e');
        // Continue without background mode if permission is denied
      }
      location.changeSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter:
              double.parse(Constant.driverLocationUpdate.toString()),
          interval: 2000);
      location.onLocationChanged.listen((locationData) {
        Constant.currentLocation = LocationLatLng(
            latitude: locationData.latitude, longitude: locationData.longitude);
        String? driverId = FireStoreUtils.getCurrentUid();
        if (driverId != null) {
          FireStoreUtils.getDriverProfile(driverId).then((value) {
            if (value != null) {
              DriverUserModel driverUserModel = value;
              if (driverUserModel.isOnline == true) {
              driverUserModel.location = LocationLatLng(
                  latitude: locationData.latitude,
                  longitude: locationData.longitude);
              GeoFirePoint position = Geoflutterfire().point(
                  latitude: locationData.latitude!,
                  longitude: locationData.longitude!);

              driverUserModel.position = Positions(
                  geoPoint: position.geoPoint, geohash: position.hash);
              driverUserModel.rotation = locationData.heading;
              FireStoreUtils.updateDriverUser(driverUserModel);
              }
            }
          });
        }
      });
    } else {
      location.requestPermission().then((permissionStatus) {
        if (permissionStatus == PermissionStatus.granted) {
          try {
            location.enableBackgroundMode(enable: true);
          } catch (e) {
            print('Background location permission denied: $e');
            // Continue without background mode if permission is denied
          }
          location.changeSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter:
                  double.parse(Constant.driverLocationUpdate.toString()),
              interval: 2000);
          location.onLocationChanged.listen((locationData) async {
            Constant.currentLocation = LocationLatLng(
                latitude: locationData.latitude,
                longitude: locationData.longitude);
            String? driverId = FireStoreUtils.getCurrentUid();
            if (driverId != null) {
              FireStoreUtils.getDriverProfile(driverId).then((value) {
                DriverUserModel driverUserModel = value!;
                if (driverUserModel.isOnline == true) {
                  driverUserModel.location = LocationLatLng(
                      latitude: locationData.latitude,
                      longitude: locationData.longitude);
                  driverUserModel.rotation = locationData.heading;
                  GeoFirePoint position = Geoflutterfire().point(
                      latitude: locationData.latitude!,
                      longitude: locationData.longitude!);

                  driverUserModel.position = Positions(
                      geoPoint: position.geoPoint, geohash: position.hash);

                  FireStoreUtils.updateDriverUser(driverUserModel);
                }
              });
            }
          });
        }
      });
    }
    isLoading.value = false;
    update();
  }
}
