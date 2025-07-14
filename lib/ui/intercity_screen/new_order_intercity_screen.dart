import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui; // Needed for map camera bounds and image codec
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/intercity_controller.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/intercity_screen/pacel_details_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class NewOrderInterCityScreen extends StatelessWidget {
  const NewOrderInterCityScreen({super.key});

  void _showRideDetailsBottomSheet(BuildContext context,
      IntercityController controller, InterCityOrderModel orderModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RideDetailBottomSheet(orderModel: orderModel),
    ).then((value) {
      // Value is `true` if "Accept Ride" was pressed
      if (value != null && value == true) {
        if (controller.driverModel.value.subscriptionTotalOrders == "-1") {
          controller.acceptOrder(orderModel);
        } else {
          if (Constant.isSubscriptionModelApplied == false &&
              Constant.adminCommission!.isEnabled == false) {
            controller.acceptOrder(orderModel);
          } else {
            controller.acceptOrder(orderModel);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetX<IntercityController>(
      init: IntercityController()..getOrder(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: AppColors.grey100,
          body: Column(
            children: [
              // Wallet Warning Banner
              if (double.parse(
                      controller.driverModel.value.walletAmount?.toString() ??
                          '0.0') <
                  double.parse(Constant.minimumDepositToRideAccept ?? '0.0'))
                _buildWalletWarningBanner(),

              Expanded(
                child: controller.isLoading.value
                    ? Constant.loader(context)
                    : controller.intercityServiceOrder.isEmpty
                        ? _buildInfoMessage("No New Rides",
                            "When a new inter-city ride is available, it will appear here.",
                            icon: Icons.explore_off_outlined)
                        : RefreshIndicator(
                            onRefresh: () => controller.getOrder(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 6),
                              itemCount:
                                  controller.intercityServiceOrder.length,
                              itemBuilder: (context, index) {
                                InterCityOrderModel orderModel =
                                    controller.intercityServiceOrder[index];
                                return _buildNewRideRequestCard(
                                    context, controller, orderModel);
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewRideRequestCard(BuildContext context,
      IntercityController controller, InterCityOrderModel orderModel) {
    bool isParcelService = orderModel.intercityServiceId == "647f350983ba2";

    return InkWell(
      onTap: () => _showRideDetailsBottomSheet(context, controller, orderModel),
      child: _buildRideCardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserView(
              userId: orderModel.userId,
              amount: orderModel.offerRate,
              distance: orderModel.distance,
              distanceType: orderModel.distanceType,
            ),
            const Divider(height: 16, color: AppColors.grey200),
            LocationView(
              sourceLocation: orderModel.sourceLocationName.toString(),
              destinationLocation:
                  orderModel.destinationLocationName.toString(),
            ),
            const Divider(height: 16, color: AppColors.grey200),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Trip Date & Time".tr,
                        style: AppTypography.caption(context)
                            .copyWith(color: AppColors.grey500)),
                    const SizedBox(height: 2),
                    Text(
                      '${orderModel.whenDates.toString()} at ${orderModel.whenTime.toString()}',
                      style: AppTypography.boldLabel(context)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (isParcelService)
                  TextButton(
                    onPressed: () {
                      Get.to(() => const ParcelDetailsScreen(),
                          arguments: {"orderModel": orderModel});
                    },
                    child: Text(
                      "View Details".tr,
                      style: AppTypography.appTitle(context),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Passengers".tr,
                          style: AppTypography.caption(context)
                              .copyWith(color: AppColors.grey500)),
                      const SizedBox(height: 2),
                      Text(
                        orderModel.numberOfPassenger.toString(),
                        style: AppTypography.headers(context)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideCardContainer({required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
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

  Widget _buildInfoMessage(String title, String subtitle, {IconData? icon}) {
    return Center(
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
              Text(
                title.tr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
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

  Widget _buildWalletWarningBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE69C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFF664D03), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Your wallet balance is low. A minimum of ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} is required to accept rides."
                  .tr,
              style: GoogleFonts.poppins(
                color: const Color(0xFF664D03),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~ RIDE DETAIL BOTTOM SHEET WIDGET ~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class RideDetailBottomSheet extends StatefulWidget {
  final InterCityOrderModel orderModel;
  const RideDetailBottomSheet({Key? key, required this.orderModel})
      : super(key: key);

  @override
  State<RideDetailBottomSheet> createState() => _RideDetailBottomSheetState();
}

class _RideDetailBottomSheetState extends State<RideDetailBottomSheet> {
  // TODO: IMPORTANT! Replace with your actual Google Maps API Key.
  // Make sure the "Directions API" is enabled in your Google Cloud Console.
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
    if (widget.orderModel.sourceLocationLAtLng!.latitude == 0 ||
        widget.orderModel.destinationLocationLAtLng!.latitude == 0) {
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
          await getBytesFromAsset('assets/images/green_mark.png', 100);
      final Uint8List destinationIcon =
          await getBytesFromAsset('assets/images/red_mark.png', 100);

      _markers.add(Marker(
        markerId: const MarkerId('source'),
        position: source,
        icon: BitmapDescriptor.fromBytes(sourceIcon),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ));

      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        icon: BitmapDescriptor.fromBytes(destinationIcon),
        infoWindow: const InfoWindow(title: 'Drop-off Location'),
      ));

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
        widget.orderModel.sourceLocationLAtLng!.longitude!);
    final LatLng destination = LatLng(
        widget.orderModel.destinationLocationLAtLng!.latitude!,
        widget.orderModel.destinationLocationLAtLng!.longitude!);

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
            _polylines.add(Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: AppColors.primary,
              width: 5,
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
          throw Exception(data['error_message'] ?? 'Failed to get directions');
        }
      } else {
        throw Exception('Failed to load directions');
      }
    } catch (e) {
      print("Error fetching directions: $e");
      if (mounted) {
        setState(() {
          _routeDistance = 'Error';
          _routeDuration = 'Error';
          _isLoadingRoute = false;
        });
      }
    }
  }

  void _fitMapToShowRoute() {
    if (_mapController == null || _markers.length < 2) return;

    final bounds =
        _boundsFromLatLngList(_markers.map((m) => m.position).toList());

    Future.delayed(const Duration(milliseconds: 50), () {
      _mapController
          ?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
    });
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
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
        southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20)),
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
                  borderRadius: BorderRadius.circular(12)),
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
                  zoom: 12,
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
              ),
              if (_isLoadingRoute)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
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
          color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
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
            onPressed: () =>
                Navigator.pop(context, true), // Return true on accept
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
