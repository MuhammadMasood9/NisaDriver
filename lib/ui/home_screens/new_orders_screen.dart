import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui; // Needed for map camera bounds and image codec
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/home_screens/order_map_screen.dart';
import 'package:driver/ui/home_screens/zone_ride_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen>
    with AutomaticKeepAliveClientMixin<NewOrderScreen> {
  final HomeController controller = Get.put(HomeController());

  Stream<List<OrderModel>>? _allNewOrdersBroadcastStream;
  Stream<QuerySnapshot>? _acceptedOrdersStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Streams are initialized in the build method to ensure they refresh
    // when the driver's online status changes.
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
    FireStoreUtils().closeStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.grey100,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Constant.loader(context);
          }

          if (_allNewOrdersBroadcastStream == null) {
            _initializeStreams();
          }

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

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _initializeStreams();
              });
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLiveRidesNavigationCard(),
                  _buildAcceptedOrdersSection(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                    child: Text(
                      "New Ride Requests".tr,
                      style: AppTypography.boldHeaders(context),
                    ),
                  ),
                  _buildNewOrdersSection(context, controller),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showRideDetailsBottomSheet(OrderModel orderModel,
      {bool isAlreadyAccepted = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RideDetailBottomSheet(
        orderModel: orderModel,
        isAlreadyAccepted: isAlreadyAccepted,
      ),
    ).then((value) {
      // This logic will now run for both new and accepted rides
      // when "Accept Ride" is clicked in the bottom sheet.
      if (value != null && value == true) {
        Get.to(() => const OrderMapScreen(),
            arguments: {"orderModel": orderModel.id.toString()});
      }
    });
  }

  Widget _buildLiveRidesNavigationCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: InkWell(
        onTap: () => Get.to(() => const RouteMatchingScreen()),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.darkModePrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkBackground.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.radar, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Route Matching Ride Finder".tr,
                        style: AppTypography.boldHeaders(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Set your destination and find rides along your route."
                            .tr,
                        style: AppTypography.boldLabel(context).copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.7)),
              ],
            ),
          ),
        ),
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
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
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

                return InkWell(
                  onTap: () => _showRideDetailsBottomSheet(orderModel,
                      isAlreadyAccepted: true),
                  child: OrderItemWithTimer(
                      key: ValueKey("accepted-${orderModel.id}"),
                      orderModel: orderModel),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 6),
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

  Widget _buildNewRideRequestCard(OrderModel orderModel, {Key? key}) => InkWell(
      key: key,
      onTap: () => _showRideDetailsBottomSheet(orderModel),
      child: _buildRideCardContainer(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildUserHeader(
            userId: orderModel.userId,
            offerRate: orderModel.offerRate,
            distance: orderModel.distance,
            distanceType: orderModel.distanceType),
        const Divider(height: 12, color: AppColors.grey200),
        _buildLocationDetailRow(
          source: orderModel.sourceLocationName.toString(),
          destination: orderModel.destinationLocationName.toString(),
        ),
      ])));

  Widget _buildRideCardContainer({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
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
        ],
      );

  Widget _buildLocationDetailRow(
          {required String source, required String destination}) =>
      LocationView(sourceLocation: source, destinationLocation: destination);

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
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~ RIDE DETAIL BOTTOM SHEET WIDGET ~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class RideDetailBottomSheet extends StatefulWidget {
  final OrderModel orderModel;
  final bool isAlreadyAccepted;

  const RideDetailBottomSheet({
    Key? key,
    required this.orderModel,
    this.isAlreadyAccepted = false,
  }) : super(key: key);

  @override
  State<RideDetailBottomSheet> createState() => _RideDetailBottomSheetState();
}

class _RideDetailBottomSheetState extends State<RideDetailBottomSheet> {
  // TODO: IMPORTANT! Replace with your actual Google Maps API Key.
  final String _googleApiKey = "AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4";

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _isLoadingRoute = true;
  String _routeDistance = '...';
  String _routeDuration = '...';

  @override
  void initState() {
    super.initState();
    _setMarkersAndDrawRoute();
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<void> _setMarkersAndDrawRoute() async {
    if (widget.orderModel.sourceLocationLAtLng?.latitude == null ||
        widget.orderModel.sourceLocationLAtLng?.longitude == null ||
        widget.orderModel.destinationLocationLAtLng?.latitude == null ||
        widget.orderModel.destinationLocationLAtLng?.longitude == null) {
      print('Error: Missing coordinates for source or destination');
      setState(() {
        _routeDistance = 'Error: Missing coordinates';
        _routeDuration = 'Error: Missing coordinates';
        _isLoadingRoute = false;
      });
      return;
    }

    final source = LatLng(
      widget.orderModel.sourceLocationLAtLng!.latitude!,
      widget.orderModel.sourceLocationLAtLng!.longitude!,
    );
    final destination = LatLng(
      widget.orderModel.destinationLocationLAtLng!.latitude!,
      widget.orderModel.destinationLocationLAtLng!.longitude!,
    );

    try {
      Uint8List? sourceIcon;
      Uint8List? destinationIcon;

      try {
        sourceIcon =
            await getBytesFromAsset('assets/images/green_mark.png', 40);
        destinationIcon =
            await getBytesFromAsset('assets/images/red_mark.png', 40);
      } catch (e) {
        print('Custom marker assets not found, using default markers: $e');
      }

      _markers.add(Marker(
        markerId: const MarkerId('source'),
        position: source,
        icon: sourceIcon != null
            ? BitmapDescriptor.fromBytes(sourceIcon)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ));

      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        icon: destinationIcon != null
            ? BitmapDescriptor.fromBytes(destinationIcon)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Drop-off Location'),
      ));

      if (mounted) setState(() {});

      await _drawRouteAndGetDetails();
    } catch (e) {
      print('Error setting markers: $e');
      setState(() {
        _routeDistance = 'Error setting markers';
        _routeDuration = 'Error setting markers';
        _isLoadingRoute = false;
      });
    }
  }

  Future<void> _drawRouteAndGetDetails() async {
    final LatLng origin = LatLng(
      widget.orderModel.sourceLocationLAtLng!.latitude!,
      widget.orderModel.sourceLocationLAtLng!.longitude!,
    );
    final LatLng destination = LatLng(
      widget.orderModel.destinationLocationLAtLng!.latitude!,
      widget.orderModel.destinationLocationLAtLng!.longitude!,
    );

    String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          final overviewPolyline = route['overview_polyline']['points'];
          final List<PointLatLng> decodedPoints =
              PolylinePoints().decodePolyline(overviewPolyline);
          final List<LatLng> routePoints = decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          if (routePoints.isNotEmpty) {
            _polylines.clear();
            _polylines.add(Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: AppColors.primary,
              width: 3,
            ));
          }

          if (mounted) {
            setState(() {
              _routeDistance = leg['distance']['text'] ?? 'N/A';
              _routeDuration = leg['duration']['text'] ?? 'N/A';
              _isLoadingRoute = false;
            });
          }
          _fitMapToShowRoute();
        } else {
          String errorMessage = data['error_message'] ?? 'No route found';
          print("Directions API Error: ${data['status']} - $errorMessage");
          if (mounted) {
            setState(() {
              _routeDistance = 'Route Error';
              _routeDuration = 'Route Error';
              _isLoadingRoute = false;
            });
          }
        }
      } else {
        print("HTTP request failed with status: ${response.statusCode}");
        if (mounted) {
          setState(() {
            _routeDistance = 'HTTP Error';
            _routeDuration = 'HTTP Error';
            _isLoadingRoute = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching directions: $e");
      if (mounted) {
        setState(() {
          _routeDistance = 'Network Error';
          _routeDuration = 'Network Error';
          _isLoadingRoute = false;
        });
      }
    }
  }

  void _fitMapToShowRoute() {
    if (_mapController == null || _markers.length < 2) return;

    final bounds = _boundsFromLatLngList(
        _markers.map((marker) => marker.position).toList());

    Future.delayed(const Duration(milliseconds: 50), () {
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80.0), // Padding
        );
      }
    });
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double minLat = list.first.latitude;
    double maxLat = list.first.latitude;
    double minLng = list.first.longitude;
    double maxLng = list.first.longitude;

    for (LatLng latLng in list) {
      minLat = min(minLat, latLng.latitude);
      maxLat = max(maxLat, latLng.latitude);
      minLng = min(minLng, latLng.longitude);
      maxLng = max(maxLng, latLng.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildMapSection(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                UserView(
                  userId: widget.orderModel.userId,
                  amount: widget.orderModel.offerRate,
                  distance: widget.orderModel.distance,
                  distanceType: widget.orderModel.distanceType,
                ),
                const Divider(height: 24),
                LocationView(
                  sourceLocation:
                      widget.orderModel.sourceLocationName.toString(),
                  destinationLocation:
                      widget.orderModel.destinationLocationName.toString(),
                ),
                const Divider(height: 24),
                _buildRouteInfoRow(),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                      widget.orderModel.sourceLocationLAtLng!.latitude!,
                      widget.orderModel.sourceLocationLAtLng!.longitude!),
                  zoom: 10,
                ),
                onMapCreated: (controller) async {
                  _mapController = controller;

                  String style =
                      await rootBundle.loadString('assets/map_style.json');
                  _mapController?.setMapStyle(style);
                  _fitMapToShowRoute();
                },
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
              ),
              if (_isLoadingRoute)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfoRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoChip(
              icon: Icons.timer_outlined, label: 'ETA', value: _routeDuration),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          _buildInfoChip(
              icon: Icons.map_outlined,
              label: 'Distance',
              value: _routeDistance),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      {required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Text(label.tr,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(value, style: AppTypography.headers(context)),
          ],
        )
      ],
    );
  }

  // MODIFICATION: Removed the condition to always show the "Accept Ride" button
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade800,
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text("Close".tr,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Pop with 'true' to indicate acceptance/navigation
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            // The button text can be dynamic if you want, but "Accept Ride" works
            // as it leads to the acceptance/negotiation screen.
            child: Text("Accept Ride".tr,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
                          // _buildUserHeader(
                          //     userId: widget.orderModel.userId,
                          //     // BUG FIX: Use finalRate but provide a default value to prevent null error.
                          //     offerRate: widget.orderModel.finalRate,
                          //     distance: widget.orderModel.distance,
                          //     distanceType: widget.orderModel.distanceType),
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
                              label: Text('Cancel Offer'.tr),
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

  // MODIFICATION: Changed how this widget is built to be more robust.
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
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Your Offer".tr,
                  style: AppTypography.caption(context)
                      .copyWith(color: Colors.grey)),
              // BUG FIX: Provide a default value for amount to avoid parse errors.
              Text(Constant.amountShow(amount: offerRate ?? "0.0"),
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
