import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui; // Needed for map camera bounds and image codec
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/home_screens/order_map_screen.dart';
import 'package:driver/ui/home_screens/zone_ride_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
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
      backgroundColor: AppColors.grey50,
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
                  const SizedBox(
                    height: 80,
                  )
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.darkModePrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.radar, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Drive Your Way, Get Paid".tr,
                        style: AppTypography.boldHeaders(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Set your destination and we'll find passengers who need a ride along your route."
                            .tr,
                        style: AppTypography.smBoldLabel(context).copyWith(
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
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
              child: Text(
                "Active Orders".tr,
                style: AppTypography.boldHeaders(context),
              ),
            ),
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
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 6),
              child: Divider(),
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

  // MODIFIED: This card now follows the design of the "Order History" screen.
  Widget _buildNewRideRequestCard(OrderModel orderModel, {Key? key}) {
    return InkWell(
        key: key,
        onTap: () => _showRideDetailsBottomSheet(orderModel),
        child: _buildRideCardContainer(
          child: Column(
            children: [
              // Pickup point and Payment row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_circle_down,
                      size: 22, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(orderModel.sourceLocationName.toString(),
                            style: AppTypography.boldLabel(context).copyWith(
                                fontWeight: FontWeight.w500, height: 1.3)),
                        Text("Pickup point".tr,
                            style: AppTypography.caption(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      Constant.amountShow(
                          amount: orderModel.offerRate.toString()),
                      style: AppTypography.boldLabel(context)
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              // Dotted line connecting the points
              Row(
                children: [
                  Container(
                    width: 22,
                    alignment: Alignment.center,
                    child: Container(
                        height: 20, width: 1.5, color: AppColors.grey200),
                  ),
                  Expanded(child: Container()),
                ],
              ),
              // Destination and Distance row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 22, color: Colors.black),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(orderModel.destinationLocationName.toString(),
                            style: AppTypography.boldLabel(context).copyWith(
                                fontWeight: FontWeight.w500, height: 1.3)),
                        Text("Destination".tr,
                            style: AppTypography.caption(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Distance".tr,
                          style: AppTypography.caption(context)),
                      Text(
                        "${(double.parse(orderModel.distance.toString())).toStringAsFixed(Constant.currencyModel!.decimalDigits!)} ${orderModel.distanceType}",
                        style: AppTypography.boldLabel(context),
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
        ));
  }

  Widget _buildRideCardContainer({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: child,
      );

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
  final String _googleApiKey =
      "AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4"; // IMPORTANT

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
      if (mounted) {
        setState(() {
          _routeDistance = 'Error';
          _routeDuration = 'Error';
          _isLoadingRoute = false;
        });
      }
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
      final Uint8List sourceIcon =
          await getBytesFromAsset('assets/images/green_mark.png', 30);
      final Uint8List destinationIcon =
          await getBytesFromAsset('assets/images/red_mark.png', 30);

      _markers.add(Marker(
          markerId: const MarkerId('source'),
          position: source,
          icon: BitmapDescriptor.fromBytes(sourceIcon),
          anchor: const Offset(0.5, 0.5)));

      _markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          icon: BitmapDescriptor.fromBytes(destinationIcon),
          anchor: const Offset(0.5, 0.5)));

      if (mounted) setState(() {});

      await _drawRouteAndGetDetails();
    } catch (e) {
      print('Error setting markers: $e');
      if (mounted) {
        setState(() {
          _routeDistance = 'Error';
          _routeDuration = 'Error';
          _isLoadingRoute = false;
        });
      }
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
                width: 2,
                patterns: <PatternItem>[
                  PatternItem.dash(20),
                  PatternItem.gap(10)
                ]));
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
      if (_mapController != null && mounted) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 40.0), // Padding
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
    // NEW: The whole sheet is built with a new method to match the image.
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
                const Divider(
                    height: 22, thickness: 1, color: AppColors.grey200),
                _buildDetailsCard(),
                const SizedBox(height: 10),
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

                  try {
                    String style =
                        await rootBundle.loadString('assets/map_style.json');
                    _mapController?.setMapStyle(style);
                  } catch (e) {
                    debugPrint("Error loading map style: $e");
                  }
                  _fitMapToShowRoute();
                },
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                compassEnabled: false,
                mapToolbarEnabled: false,
              ),
              if (_isLoadingRoute)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: A detailed card that mimics the grid from the example image.
  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildDetailItem(
            'Ride Fare'.tr,
            Constant.amountShow(amount: widget.orderModel.offerRate),
            AppColors.primary,
          ),
          _buildDetailItem(
            'Distance'.tr,
            _isLoadingRoute ? '...' : _routeDistance,
            Colors.black87,
          ),
          _buildDetailItem(
            'Duration'.tr,
            _isLoadingRoute ? '...' : _routeDuration,
            Colors.black87,
          ),
          _buildDetailItem(
            'Payment'.tr,
            widget.orderModel.paymentType.toString(),
            Colors.black87,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String title, String value, Color valueColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.caption(context).copyWith(
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.appTitle(context).copyWith(
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // NEW: Styled action buttons
  Widget _buildActionButtons() {
    if (widget.isAlreadyAccepted) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text("Close".tr,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }
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
            child: Text("Decline".tr,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Passing true signals to accept the ride
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
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

  // MODIFIED: This widget now follows the consistent "Order History" card design.
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _isExpired.value
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      spreadRadius: 1,
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    )
                  ]),
              child: Column(
                children: [
                  TimerIndicator(remainingSeconds: _remainingSeconds),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // NEW: Location and payment block for accepted orders.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.arrow_circle_down,
                                size: 22, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      widget.orderModel.sourceLocationName
                                          .toString(),
                                      style: AppTypography.boldLabel(context)
                                          .copyWith(
                                              fontWeight: FontWeight.w500,
                                              height: 1.3)),
                                  Text("Pickup point".tr,
                                      style: AppTypography.caption(context)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 22,
                              alignment: Alignment.center,
                              child: Container(
                                  height: 20,
                                  width: 1.5,
                                  color: AppColors.grey200),
                            ),
                            Expanded(child: Container()),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on,
                                size: 22, color: Colors.black),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      widget.orderModel.destinationLocationName
                                          .toString(),
                                      style: AppTypography.boldLabel(context)
                                          .copyWith(
                                              fontWeight: FontWeight.w500,
                                              height: 1.3)),
                                  Text("Destination".tr,
                                      style: AppTypography.caption(context)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }
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
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: timerColor.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Center(
              child: Text(
                'Awaiting Confirmation: $seconds s'.tr,
                style: GoogleFonts.poppins(
                  color: timerColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.transparent,
            color: timerColor,
            minHeight: 4,
          ),
        ],
      );
    });
  }
}
