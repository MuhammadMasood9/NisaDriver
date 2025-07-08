import 'dart:async';
import 'dart:math'; // Needed for min/max
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/zone_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/home_screens/order_map_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator for distance calculation
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Main Screen Widget
class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<NewOrderScreen> {
  late TabController _tabController;
  final HomeController controller = Get.put(HomeController());
  int _selectedTabIndex = 0;

  Stream<List<OrderModel>>? _allNewOrdersBroadcastStream;
  Stream<QuerySnapshot>? _acceptedOrdersStream;

  // ~~~ State for the Online (Zoned) Map Tab ~~~
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles =
      {}; // Use Circles instead of Polygons for driver zone
  Set<Polygon> _adminZonePolygons = {}; // To hold the fetched admin zones
  bool _isLoadingAdminZone = true;

  LatLng? _zoneCenter;
  double _zoneRadiusInMeters = 2000; // Default radius of 2km
  bool _isZoneActive = false;

  OrderModel? _zonedRide;
  StreamSubscription? _zonedRideSubscription;
  final Set<String> _shownRidePopups = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedTabIndex) {
        if (mounted) {
          setState(() => _selectedTabIndex = _tabController.index);
        }
      }
    });

    _fetchAndDrawAdminZones();
  }

  void _initializeStreams() {
    _acceptedOrdersStream = FirebaseFirestore.instance
        .collection(CollectionName.orders)
        .where('acceptedDriverId',
            arrayContains: FireStoreUtils.getCurrentUid())
        .snapshots();

    _allNewOrdersBroadcastStream = FireStoreUtils()
        .getOrders(
          controller.driverModel.value,
          Constant.currentLocation?.latitude,
          Constant.currentLocation?.longitude,
        )
        .asBroadcastStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mapController?.dispose();
    _zonedRideSubscription?.cancel();
    FireStoreUtils().closeStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.grey50,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Constant.loader(context);
          }

          if (_allNewOrdersBroadcastStream == null) {
            _initializeStreams();
          }

          return Column(
            children: [
              _buildTabSwitcher(context),
              Expanded(
                child: Stack(
                  children: [
                    TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildOfflineView(context, controller),
                        _buildOnlineView(context),
                      ],
                    ),
                    if (_zonedRide != null) _buildZonedRidePopup(_zonedRide!),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Modern, animated tab switcher replacing the default TabBar.
  Widget _buildTabSwitcher(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(25.0),
        ),
        child: Row(
          children: [
            _buildTabItem(context, "Offline", 0),
            _buildTabItem(context, "Online (Zoned)", 1),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, String title, int index) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(21.0),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              title.tr,
              style: AppTypography.appTitle(context).copyWith(
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // ~~~~~~~~~~~~~~~~~~~~~~ OFFLINE TAB IMPLEMENTATION ~~~~~~~~~~~~~~~~~~~~
  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  Widget _buildOfflineView(BuildContext context, HomeController controller) {
    if (controller.driverModel.value.isOnline == false) {
      return _buildInfoMessage("You Are Offline",
          "Go online from the dashboard to see new ride requests.",
          icon: Icons.wifi_off_rounded);
    }
    if (controller.driverModel.value.documentVerification == false) {
      return _buildInfoMessage("Documents Not Verified",
          "Please complete document verification to receive ride orders.",
          icon: Icons.description_outlined);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAcceptedOrdersSection(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Text(
              "New Ride Requests".tr,
              style: AppTypography.boldHeaders(context),
            ),
          ),
          _buildNewOrdersSection(context, controller),
        ],
      ),
    );
  }

  Widget _buildAcceptedOrdersSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _acceptedOrdersStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Accepted - Awaiting Confirmation".tr,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              itemCount: snapshot.data!.docs.length,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemBuilder: (context, index) {
                OrderModel orderModel = OrderModel.fromJson(
                    snapshot.data!.docs[index].data() as Map<String, dynamic>);
                return OrderItemWithTimer(
                    key: ValueKey("accepted-${orderModel.id}"),
                    orderModel: orderModel);
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16),
              child: Divider(thickness: 1.5),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNewOrdersSection(
      BuildContext context, HomeController controller) {
    return StreamBuilder<List<OrderModel>>(
      stream: _allNewOrdersBroadcastStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Constant.loader(context);
        }
        if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
          return _buildInfoMessage(
              "All Caught Up!", "No new rides found nearby.",
              icon: Icons.done_all_rounded);
        } else {
          return ListView.builder(
            itemCount: snapshot.data!.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              OrderModel orderModel = snapshot.data![index];
              return _buildNewRideRequestCard(orderModel,
                  key: ValueKey("new-${orderModel.id}"));
            },
          );
        }
      },
    );
  }

  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  // ~~~~~~~~~~~~~~~~~~~~~~ ONLINE TAB IMPLEMENTATION ~~~~~~~~~~~~~~~~~~~~~
  // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  /// Fetches the admin-defined zones for the current driver and draws them.
  Future<void> _fetchAndDrawAdminZones() async {
    List<ZoneModel>? allZones = await FireStoreUtils.getZone();
    List<Polygon> zones = [];

    if (allZones != null && controller.driverModel.value.zoneIds != null) {
      for (String zoneId in controller.driverModel.value.zoneIds!) {
        final zoneDoc = allZones.firstWhereOrNull((z) => z.id == zoneId);
        if (zoneDoc != null && zoneDoc.area != null) {
          final points = zoneDoc.area!
              .map((geoPoint) => LatLng(geoPoint.latitude, geoPoint.longitude))
              .toList();

          if (points.length > 2) {
            zones.add(Polygon(
              polygonId: PolygonId(zoneId),
              points: points,
              strokeWidth: 2,
              strokeColor: AppColors.primary.withOpacity(0.8),
              fillColor: AppColors.primary.withOpacity(0.1),
            ));
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _adminZonePolygons = Set<Polygon>.from(zones);
        _isLoadingAdminZone = false;
      });
    }
  }

  /// Builds the main view for the Online (Zoned) tab.
  Widget _buildOnlineView(BuildContext context) {
    final initialCameraPosition = CameraPosition(
      target: LatLng(Constant.currentLocation?.latitude ?? 37.7749,
          Constant.currentLocation?.longitude ?? -122.4194),
      zoom: 12,
    );

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(10)),
                child: GoogleMap(
                  initialCameraPosition: initialCameraPosition,
                  onMapCreated: (mapController) =>
                      _mapController = mapController,
                  onTap: _isZoneActive ? null : _handleMapTap,
                  markers: _markers,
                  polygons: _adminZonePolygons, // Only show admin zones here
                  circles: _circles, // Show driver's circular zone
                  myLocationButtonEnabled: true,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),
              ),
              if (_isLoadingAdminZone) const CircularProgressIndicator(),
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: _buildMapInstructions(),
              ),
            ],
          ),
        ),
        _buildZoneControls(),
      ],
    );
  }

  /// Main handler for taps on the map to set the circular zone.
  void _handleMapTap(LatLng position) {
    if (_isLoadingAdminZone || _adminZonePolygons.isEmpty) return;

    bool isPointInAnyAdminZone =
        _isPointInPolygon(position, _adminZonePolygons);

    if (!isPointInAnyAdminZone) {
      Get.snackbar(
        "Outside Operational Area".tr,
        "Please select a center point inside your assigned zones.".tr,
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      _zoneCenter = position;
      _updateDriverZone();
    });
  }

  /// Creates or updates the driver's circular zone on the map.
  void _updateDriverZone() {
    if (_zoneCenter == null) return;
    _markers.clear();
    _circles.clear();

    // Add marker for the center
    _markers.add(Marker(
      markerId: const MarkerId('zone_center'),
      position: _zoneCenter!,
      infoWindow: InfoWindow(title: 'Zone Center'.tr),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ));

    // Add the circle for the zone
    _circles.add(Circle(
      circleId: const CircleId('driver_zone'),
      center: _zoneCenter!,
      radius: _zoneRadiusInMeters,
      strokeWidth: 2,
      strokeColor: Colors.blue,
      fillColor: Colors.blue.withOpacity(0.25),
    ));
  }

  /// Resets all driver selections on the map.
  void _resetZoneSelection() {
    setState(() {
      _markers.clear();
      _circles.clear();
      _zoneCenter = null;
      _zoneRadiusInMeters = 2000; // Reset to default
    });
  }

  Widget _buildMapInstructions() {
    String instruction;
    Color color;

    if (_isLoadingAdminZone) {
      instruction = "Loading your operational zones...".tr;
      color = Colors.grey;
    } else if (_adminZonePolygons.isEmpty) {
      instruction = "No operational zones assigned. Contact admin.".tr;
      color = Colors.orange;
    } else if (_isZoneActive) {
      instruction = "Listening for rides in your selected zone.".tr;
      color = Colors.green;
    } else if (_zoneCenter == null) {
      instruction = "Tap inside a shaded area to set ZONE CENTER.".tr;
      color = AppColors.primary;
    } else {
      instruction = "Zone set. Press 'Start Listening' to begin.".tr;
      color = Colors.blue;
    }

    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(
          instruction,
          style: AppTypography.boldLabel(context).copyWith(
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildZoneControls() {
    bool canListen = _zoneCenter != null;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Zone Radius:".tr,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              Text("${(_zoneRadiusInMeters / 1000).toStringAsFixed(1)} km".tr,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: _zoneRadiusInMeters,
            min: 500, // 0.5 km
            max: 10000, // 10 km
            divisions: 19,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primary.withOpacity(0.2),
            onChanged: _isZoneActive
                ? null
                : (value) {
                    setState(() {
                      _zoneRadiusInMeters = value;
                      _updateDriverZone();
                    });
                  },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _isZoneActive ? null : _resetZoneSelection,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Icon(Icons.refresh,
                      color: Colors.grey.shade700, size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: Icon(_isZoneActive
                        ? Icons.stop_circle_outlined
                        : Icons.radar),
                    label: Text(
                        _isZoneActive
                            ? "Stop Listening".tr
                            : "Start Listening".tr,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: (canListen || _isZoneActive)
                        ? _toggleZoneListening
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isZoneActive
                          ? Colors.red.shade600
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleZoneListening() {
    if (_isZoneActive) {
      setState(() {
        _isZoneActive = false;
        _zonedRideSubscription?.cancel();
        _zonedRide = null;
        _shownRidePopups.clear();
      });
      _resetZoneSelection();
      Get.snackbar("Zone Deactivated", "You have stopped listening for rides.",
          snackPosition: SnackPosition.BOTTOM);
    } else {
      if (_zoneCenter == null) return;
      setState(() => _isZoneActive = true);
      _listenForZonedRides();
      Get.snackbar("Zone Activated!", "Listening for rides in your area.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white);
    }
  }

  Future<void> _listenForZonedRides() async {
    if (_zoneCenter == null || _allNewOrdersBroadcastStream == null) return;

    _zonedRideSubscription = _allNewOrdersBroadcastStream!.listen((orders) {
      if (!mounted || !_isZoneActive) return;

      final potentialRide = orders.firstWhereOrNull((order) {
        if (_shownRidePopups.contains(order.id) ||
            order.sourceLocationLAtLng?.latitude == null ||
            order.sourceLocationLAtLng?.longitude == null) {
          return false;
        }

        final ridePickupPoint = LatLng(order.sourceLocationLAtLng!.latitude!,
            order.sourceLocationLAtLng!.longitude!);

        // Calculate distance from zone center to ride pickup
        final distance = Geolocator.distanceBetween(
          _zoneCenter!.latitude,
          _zoneCenter!.longitude,
          ridePickupPoint.latitude,
          ridePickupPoint.longitude,
        );

        return distance <= _zoneRadiusInMeters;
      });

      if (potentialRide != null) {
        setState(() {
          _zonedRide = potentialRide;
          _shownRidePopups.add(potentialRide.id!);
        });
      }
    });
  }

  bool _isPointInPolygon(LatLng point, Set<Polygon> polygons) {
    for (final polygon in polygons) {
      int intersections = 0;
      List<LatLng> polygonPoints = polygon.points;
      for (int i = 0; i < polygonPoints.length; i++) {
        LatLng p1 = polygonPoints[i];
        LatLng p2 = polygonPoints[(i + 1) % polygonPoints.length];
        if (p1.longitude == p2.longitude &&
            point.longitude == p1.longitude &&
            point.latitude >= min(p1.latitude, p2.latitude) &&
            point.latitude <= max(p1.latitude, p2.latitude)) {
          return true;
        }
        if (point.longitude > min(p1.longitude, p2.longitude) &&
            point.longitude <= max(p1.longitude, p2.longitude) &&
            point.latitude <= max(p1.latitude, p2.latitude) &&
            p1.longitude != p2.longitude) {
          double xinters = (point.longitude - p1.longitude) *
                  (p2.latitude - p1.latitude) /
                  (p2.longitude - p1.longitude) +
              p1.latitude;
          if (p1.latitude == p2.latitude || point.latitude <= xinters) {
            intersections++;
          }
        }
      }
      if (intersections % 2 != 0) {
        return true; // Point is in this polygon
      }
    }
    return false; // Point is not in any of the polygons
  }

  Widget _buildNewRideRequestCard(OrderModel orderModel, {Key? key}) => InkWell(
      key: key,
      onTap: () {
        Get.to(() => const OrderMapScreen(),
            arguments: {"orderModel": orderModel.id.toString()})?.then((value) {
          if (value != null && value == true) {
            controller.selectedIndex.value = 1;
          }
        });
      },
      child: _buildRideCardContainer(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildUserHeader(
            userId: orderModel.userId,
            offerRate: orderModel.offerRate,
            distance: orderModel.distance,
            distanceType: orderModel.distanceType),
        const Divider(height: 24, color: AppColors.grey200),
        _buildLocationDetailRow(
          source: orderModel.sourceLocationName.toString(),
          destination: orderModel.destinationLocationName.toString(),
        ),
        const SizedBox(height: 16),
        _buildRecommendedPriceBanner(orderModel),
      ])));

  Widget _buildRideCardContainer({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      );

  Widget _buildUserHeader(
          {String? userId,
          String? offerRate,
          String? distance,
          String? distanceType}) =>
      Row(
        children: [
          Expanded(
              child: UserView(
            userId: userId,
            distance: distance,
            distanceType: distanceType,
            amount: offerRate,
          )),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Offer".tr,
                  style: AppTypography.headers(context)
                      .copyWith(color: Colors.grey)),
              Text(
                Constant.amountShow(amount: offerRate ?? '0'),
                style: AppTypography.appTitle(context)
                    .copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ],
      );

  Widget _buildLocationDetailRow(
          {required String source, required String destination}) =>
      LocationView(sourceLocation: source, destinationLocation: destination);

  Widget _buildRecommendedPriceBanner(OrderModel orderModel) {
    String amount;
    if (Constant.distanceType == "Km") {
      amount = Constant.amountCalculate(orderModel.service!.kmCharge.toString(),
              orderModel.distance.toString())
          .toStringAsFixed(Constant.currencyModel!.decimalDigits!);
    } else {
      amount = Constant.amountCalculate(orderModel.service!.kmCharge.toString(),
              orderModel.distance.toString())
          .toStringAsFixed(Constant.currencyModel!.decimalDigits!);
    }
    final distanceValue =
        double.tryParse(orderModel.distance.toString()) ?? 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          'Recommended: ${Constant.amountShow(amount: amount)} for approx ${distanceValue.toStringAsFixed(1)} ${Constant.distanceType}',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: AppColors.primary.withOpacity(0.9)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildInfoMessage(String title, String subtitle,
          {IconData? icon, Color? color}) =>
      Center(
        child: Opacity(
          opacity: 0.7,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  Icon(icon, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 24),
                Text(title.tr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    )),
                const SizedBox(height: 8),
                Text(
                  subtitle.tr,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildZonedRidePopup(OrderModel order) => Positioned(
        bottom: 16,
        left: 16,
        right: 16,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              onTap: () {
                setState(() => _zonedRide = null);
                Get.to(() => const OrderMapScreen(),
                    arguments: {"orderModel": order.id.toString()});
              },
              leading: const Icon(Icons.notifications_active,
                  color: Colors.white, size: 30),
              title: Text("New Zoned Ride!".tr,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text("Tap to view details and accept.".tr,
                  style: const TextStyle(color: Colors.white70)),
              trailing:
                  const Icon(Icons.arrow_forward_ios, color: Colors.white),
            ),
          ),
        ),
      );
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~ WIDGETS FROM YOUR ORIGINAL CODE (ADAPTED) ~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class OrderItemWithTimer extends StatefulWidget {
  final OrderModel orderModel;
  const OrderItemWithTimer({Key? key, required this.orderModel})
      : super(key: key);
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    String? currentUid = FireStoreUtils.getCurrentUid();
    if (currentUid != null) {
      _driverIdAcceptReject = await FireStoreUtils.getAcceptedOrders(
          widget.orderModel.id.toString(), currentUid);
      if (mounted) setState(() {});
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds.value > 0) {
        _remainingSeconds.value--;
      } else {
        _timer?.cancel();
        if (mounted) {
          _isExpired.value = true;
        }
        _handleExpiredTimer();
      }
    });
  }

  Future<void> _handleExpiredTimer() async {
    String? driverId = FireStoreUtils.getCurrentUid();
    if (driverId == null || widget.orderModel.id == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(CollectionName.orders)
          .doc(widget.orderModel.id)
          .update({
        'acceptedDriverId': FieldValue.arrayRemove([driverId])
      });
    } catch (e) {
      debugPrint("Error updating order on timer expiry: $e");
    }
  }

  Future<void> _cancelRide() async {
    _timer?.cancel();
    if (mounted) {
      _isExpired.value = true;
    }
    await _handleExpiredTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _isExpired.value
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      spreadRadius: 1,
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    )
                  ]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    TimerIndicator(remainingSeconds: _remainingSeconds),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildUserHeader(
                            userId: widget.orderModel.userId,
                            offerRate: _driverIdAcceptReject?.offerAmount,
                          ),
                          const Divider(height: 24, color: AppColors.grey200),
                          _buildLocationDetailRow(
                            source:
                                widget.orderModel.sourceLocationName.toString(),
                            destination: widget
                                .orderModel.destinationLocationName
                                .toString(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.cancel_outlined),
                              label: Text('Cancel'.tr),
                              onPressed: _cancelRide,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                foregroundColor: Colors.red.shade700,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.red.shade200),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserHeader({String? userId, String? offerRate}) => Row(
        children: [
          Expanded(
            child: UserView(
              userId: userId,
              distance: widget.orderModel.distance,
              distanceType: widget.orderModel.distanceType,
              amount: offerRate,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Your Offer".tr,
                  style: AppTypography.headers(context)
                      .copyWith(color: Colors.grey)),
              Text(Constant.amountShow(amount: offerRate),
                  style: AppTypography.appTitle(context)
                      .copyWith(color: AppColors.primary)),
            ],
          )
        ],
      );

  Widget _buildLocationDetailRow(
          {required String source, required String destination}) =>
      LocationView(sourceLocation: source, destinationLocation: destination);
}

class TimerIndicator extends StatelessWidget {
  final RxInt remainingSeconds;
  const TimerIndicator({Key? key, required this.remainingSeconds})
      : super(key: key);
  Color _getTimerColor(int seconds) {
    if (seconds > 20) return Colors.green;
    if (seconds > 10) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      int seconds = remainingSeconds.value;
      double progress = seconds / 30.0;
      Color timerColor = _getTimerColor(seconds);

      return Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            child: Center(
              child: Text(
                'Awaiting Confirmation: $seconds s'.tr,
                style: GoogleFonts.poppins(
                  color: timerColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: timerColor.withOpacity(0.2),
            color: timerColor,
            minHeight: 5,
          ),
        ],
      );
    });
  }
}
