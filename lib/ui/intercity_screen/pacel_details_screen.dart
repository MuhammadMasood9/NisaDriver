import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:clipboard/clipboard.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/parcel_details_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/widget/location_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class ParcelDetailsScreen extends StatefulWidget {
  const ParcelDetailsScreen({Key? key}) : super(key: key);

  @override
  State<ParcelDetailsScreen> createState() => _ParcelDetailsScreenState();
}

class _ParcelDetailsScreenState extends State<ParcelDetailsScreen>
    with SingleTickerProviderStateMixin {
  final ParcelDetailsController controller = Get.put(ParcelDetailsController());

  // --- State Variables ---
  // FIXED: Removed 'final' to allow reassignment in setState
  Set<Marker> _markers = {};
  List<LatLng> _polylineCoordinates = [];

  LatLngBounds? _bounds;
  String _routeDistance = '...';
  String _routeDuration = '...';
  bool _isLoadingRoute = true;
  String _mapStyle = '';

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  // --- Constants for consistent UI ---
  static const double _cardBorderRadius = 12.0;
  static const EdgeInsets _cardPadding = EdgeInsets.all(16.0);
  static const SizedBox _verticalSpacing = SizedBox(height: 12.0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadMapStyle();
      await initializeMapData();
      _animationController!.forward();
    });
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
    } catch (e) {
      debugPrint("Could not load map style: $e");
    }
  }

  Future<void> initializeMapData() async {
    if (!mounted) return;
    setState(() => _isLoadingRoute = true);
    await _addMarkers();
    await _getDirectionsAndRouteInfo();
    if (mounted) {
      setState(() => _isLoadingRoute = false);
    }
  }

  Future<BitmapDescriptor> getMarkerIcon(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    final bytes = (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _addMarkers() async {
    final orderModel = controller.orderModel.value;
    final LatLng sourceLatLng = LatLng(
      orderModel.sourceLocationLAtLng?.latitude ?? 24.905702,
      orderModel.sourceLocationLAtLng?.longitude ?? 67.072256,
    );
    final LatLng destinationLatLng = LatLng(
      orderModel.destinationLocationLAtLng?.latitude ?? 24.944788,
      orderModel.destinationLocationLAtLng?.longitude ?? 67.063066,
    );

    final iconStart = await getMarkerIcon('assets/images/green_mark.png', 50);
    final iconEnd = await getMarkerIcon('assets/images/red_mark.png', 50);

    if (mounted) {
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('source'),
            position: sourceLatLng,
            icon: iconStart,
          ),
          Marker(
            markerId: const MarkerId('destination'),
            position: destinationLatLng,
            icon: iconEnd,
          ),
        };
      });
    }
  }

  Future<void> _getDirectionsAndRouteInfo() async {
    final orderModel = controller.orderModel.value;
    final LatLng source = LatLng(
      orderModel.sourceLocationLAtLng?.latitude ?? 24.905702,
      orderModel.sourceLocationLAtLng?.longitude ?? 67.072256,
    );
    final LatLng destination = LatLng(
      orderModel.destinationLocationLAtLng?.latitude ?? 24.944788,
      orderModel.destinationLocationLAtLng?.longitude ?? 67.063066,
    );

    String apiKey = Constant.mapAPIKey;
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          final overviewPolyline = route['overview_polyline']['points'];
          final decodedPoints =
              PolylinePoints().decodePolyline(overviewPolyline);

          if (mounted) {
            setState(() {
              _routeDistance = leg['distance']['text'];
              _routeDuration = leg['duration']['text'];
              _polylineCoordinates = decodedPoints
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList();
              final boundsData = route['bounds'];
              _bounds = LatLngBounds(
                southwest: LatLng(boundsData['southwest']['lat'],
                    boundsData['southwest']['lng']),
                northeast: LatLng(boundsData['northeast']['lat'],
                    boundsData['northeast']['lng']),
              );
            });
          }
        } else {
          debugPrint(
              "Directions API Error: ${data['error_message'] ?? data['status']}");
        }
      } else {
        debugPrint("HTTP Error fetching directions: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Exception fetching directions: $e");
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetX<ParcelDetailsController>(
      builder: (controller) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: AppColors.background,
          appBar: AppBar(
            surfaceTintColor: AppColors.background,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => Get.back(),
                borderRadius: BorderRadius.circular(100),
                child: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.arrow_back_ios_new,
                      color: AppColors.primary, size: 18),
                ),
              ),
            ),
            centerTitle: true,
          ),
          body: controller.isLoading.value
              ? Constant.loader(context)
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          controller.orderModel.value.sourceLocationLAtLng
                                  ?.latitude ??
                              24.905702,
                          controller.orderModel.value.sourceLocationLAtLng
                                  ?.longitude ??
                              67.072256,
                        ),
                        zoom: 12,
                      ),
                      markers: _markers,
                      polylines: {
                        if (_polylineCoordinates.isNotEmpty)
                          Polyline(
                            polylineId: const PolylineId('route'),
                            points: _polylineCoordinates,
                            color: AppColors.primary,
                            width: 2,
                            patterns: [
                              PatternItem.dash(20),
                              PatternItem.gap(10)
                            ],
                          ),
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onMapCreated: (GoogleMapController mapController) {
                        if (_mapStyle.isNotEmpty) {
                          mapController.setMapStyle(_mapStyle);
                        }
                        if (_bounds != null) {
                          mapController.animateCamera(
                              CameraUpdate.newLatLngBounds(_bounds!, 100));
                        }
                      },
                    ),
                    DraggableScrollableSheet(
                      initialChildSize: 0.45,
                      minChildSize: 0.45,
                      maxChildSize: 0.9,
                      builder: (BuildContext context,
                          ScrollController scrollController) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: AppColors.grey75,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                  blurRadius: 20,
                                  color: Colors.black12,
                                  spreadRadius: 5)
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(28)),
                            child: SingleChildScrollView(
                              controller: scrollController,
                              child: Column(
                                children: [
                                  _buildDragHandle(),
                                  FadeTransition(
                                    opacity: _fadeAnimation!,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Column(
                                        children: [
                                          _buildOrderIdSection(context),
                                          _verticalSpacing,
                                          _buildLocationSection(context),
                                          _verticalSpacing,
                                          _buildParcelDetailsSection(context),
                                          _verticalSpacing,
                                          _buildImageGallery(context),
                                          const SizedBox(height: 50),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      padding: _cardPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: AppTypography.appTitle(context),
      ),
    );
  }

  Widget _buildOrderIdSection(BuildContext context) {
    return _buildInfoCard(
      child: Row(
        children: [
          const Icon(Icons.confirmation_number_outlined,
              color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order ID".tr,
                    style: AppTypography.label(context).copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  "#${controller.orderModel.value.id?.toUpperCase() ?? 'N/A'}",
                  style: AppTypography.boldLabel(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              FlutterClipboard.copy(controller.orderModel.value.id.toString())
                  .then((_) => ShowToastDialog.showToast("Order ID copied".tr));
            },
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child:
                  Icon(Icons.copy_rounded, size: 22, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(context, "Route Details".tr),
          const Divider(color: AppColors.grey200, height: 1),
          const SizedBox(height: 12),
          LocationView(
            sourceLocation:
                controller.orderModel.value.sourceLocationName.toString(),
            destinationLocation:
                controller.orderModel.value.destinationLocationName.toString(),
          ),
          const Divider(height: 20, color: AppColors.grey100),
          if (_isLoadingRoute)
            const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRouteStatItem(context, Icons.route_outlined,
                    "Distance".tr, _routeDistance),
                _buildRouteStatItem(context, Icons.timer_outlined,
                    "Est. Time".tr, _routeDuration),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildRouteStatItem(
      BuildContext context, IconData icon, String title, String value) {
    return Column(
      children: [
        Text(title, style: AppTypography.caption(context)),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.boldLabel(context)),
      ],
    );
  }

  Widget _buildParcelDetailsSection(BuildContext context) {
    final order = controller.orderModel.value;
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(context, "Parcel Information".tr),
          const Divider(color: AppColors.grey200, height: 1),
          const SizedBox(height: 12),
          _buildSummaryRow(
            title: "Parcel Type".tr,
            value: order.parcelDimension ?? 'N/A',
          ),
          const Divider(height: 20, color: AppColors.grey100),
          _buildSummaryRow(
            title: "Weight".tr,
            value: "${order.parcelWeight} kg",
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(BuildContext context) {
    final images = controller.orderModel.value.parcelImage ?? [];
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(context, "Parcel Images".tr),
          const Divider(color: AppColors.grey200, height: 1),
          const SizedBox(height: 12),
          images.isEmpty
              ? Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "No Images Available".tr,
                        style: AppTypography.label(context)
                            .copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: images.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: images[index].toString(),
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              color: Colors.grey.shade500,
                              size: 32,
                            ),
                          ),
                        ),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: AppTypography.label(context)
                  .copyWith(color: AppColors.grey500)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.boldLabel(context),
            ),
          ),
        ],
      ),
    );
  }
}
