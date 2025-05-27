import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/parcel_details_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:math';

class ParcelDetailsScreen extends StatefulWidget {
  const ParcelDetailsScreen({super.key});

  @override
  State<ParcelDetailsScreen> createState() => _ParcelDetailsScreenState();
}

class _ParcelDetailsScreenState extends State<ParcelDetailsScreen>
    with SingleTickerProviderStateMixin {
  final ParcelDetailsController controller = Get.put(ParcelDetailsController());
  final PolylinePoints polylinePoints = PolylinePoints();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _polylineCoordinates = [];
  LatLngBounds? _bounds;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  GoogleMapController? _mapController;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut);
    _animationController!.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeMapData();
    });
  }

  Future<void> initializeMapData() async {
    try {
      await addMarkersAndPolylines();
      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
      }
    } catch (e) {
      print('Error initializing map data: $e');
    }
  }

  Future<void> addMarkersAndPolylines() async {
    final orderModel = controller.orderModel.value;

    if (orderModel == null) {
      print('Order model is null');
      return;
    }

    double sourceLat =
        orderModel.sourceLocationLAtLng?.latitude ?? 24.905702181412074;
    double sourceLng =
        orderModel.sourceLocationLAtLng?.longitude ?? 67.07225639373064;
    double destLat =
        orderModel.destinationLocationLAtLng?.latitude ?? 24.94478876378326;
    double destLng =
        orderModel.destinationLocationLAtLng?.longitude ?? 67.06306681036949;

    if (sourceLat.isNaN || sourceLng.isNaN || destLat.isNaN || destLng.isNaN) {
      print('Invalid coordinates detected');
      sourceLat = 24.905702181412074;
      sourceLng = 67.07225639373064;
      destLat = 24.94478876378326;
      destLng = 67.06306681036949;
    }

    final LatLng sourceLatLng = LatLng(sourceLat, sourceLng);
    final LatLng destinationLatLng = LatLng(destLat, destLng);

    _bounds = LatLngBounds(
      southwest: LatLng(
        min(sourceLatLng.latitude, destinationLatLng.latitude) - 0.01,
        min(sourceLatLng.longitude, destinationLatLng.longitude) - 0.01,
      ),
      northeast: LatLng(
        max(sourceLatLng.latitude, destinationLatLng.latitude) + 0.01,
        max(sourceLatLng.longitude, destinationLatLng.longitude) + 0.01,
      ),
    );

    BitmapDescriptor pickupIcon =
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    BitmapDescriptor dropoffIcon =
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

    try {
      final customPickupIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/green_mark.png',
      );
      final customDropoffIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/red_mark.png',
      );
      pickupIcon = customPickupIcon;
      dropoffIcon = customDropoffIcon;
    } catch (e) {
      print('Using default marker icons due to error: $e');
    }

    final Set<Marker> newMarkers = {
      Marker(
        markerId: const MarkerId('pickup_location'),
        position: sourceLatLng,
        icon: pickupIcon,
        infoWindow: InfoWindow(
          title: 'Pickup Location',
          snippet: orderModel.sourceLocationName ?? 'Source location',
        ),
      ),
      Marker(
        markerId: const MarkerId('dropoff_location'),
        position: destinationLatLng,
        icon: dropoffIcon,
        infoWindow: InfoWindow(
          title: 'Drop-off Location',
          snippet: orderModel.destinationLocationName ?? 'Destination location',
        ),
      ),
    };

    setState(() {
      _markers = newMarkers;
    });

    try {
      _polylineCoordinates =
          await _getPolylinePoints(sourceLatLng, destinationLatLng);

      if (_polylineCoordinates.isNotEmpty) {
        final Set<Polyline> newPolylines = {
          Polyline(
            polylineId: const PolylineId('parcel_route'),
            points: _polylineCoordinates,
            color: AppColors.primary,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
        setState(() {
          _polylines = newPolylines;
        });
      }
    } catch (e) {
      print('Error getting polyline: $e');
    }
  }

  Future<List<LatLng>> _getPolylinePoints(
      LatLng source, LatLng destination) async {
    List<LatLng> polylineCoordinates = [];
    try {
      PolylineRequest request = PolylineRequest(
        origin: PointLatLng(source.latitude, source.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
      );

      List<PolylineResult> results =
          await polylinePoints.getRouteBetweenCoordinates(
        request: request,
        googleApiKey: 'AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4',
      );

      if (results.isNotEmpty && results[0].points.isNotEmpty) {
        polylineCoordinates = results[0]
            .points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      } else {
        polylineCoordinates = [source, destination];
      }
    } catch (e) {
      print('Error fetching polyline: $e');
      polylineCoordinates = [source, destination];
    }
    return polylineCoordinates;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController!.setMapStyle('''
      [
        {"featureType": "all", "elementType": "labels", "stylers": [{"visibility": "on"}]},
        {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#e0e0e0"}]},
        {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#c4e4ff"}]},
        {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "simplified"}]}
      ]
    ''');

    if (_bounds != null && _markers.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_mapController != null && mounted) {
          try {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(_bounds!, 100),
            );
          } catch (e) {
            print('Error fitting bounds: $e');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<ParcelDetailsController>(
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
              onPressed: () => Get.back(),
            ),
            centerTitle: true,
            title: Text(
              "Parcel Details".tr,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: AppColors.darkBackground,
              ),
            ),
          ),
          backgroundColor: themeChange.getThem()
              ? AppColors.darkBackground
              : AppColors.background,
          body: controller.isLoading.value
              ? Constant.loader(context)
              : FadeTransition(
                  opacity: _fadeAnimation!,
                  child: SingleChildScrollView(
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMapSection(context),
                            const SizedBox(height: 24),
                            _buildSectionHeader("Parcel Information".tr),
                            _buildSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryRow(
                                    title: "Order Status".tr,
                                    value: controller.orderModel.value.status ??
                                        'N/A',
                                  ),
                                  const Divider(height: 24, thickness: 1),
                                  _buildSummaryRow(
                                    title: "Payment Status".tr,
                                    value: controller
                                            .orderModel.value.paymentStatus!
                                        ? "Paid"
                                        : "Pending",
                                  ),
                                  const Divider(height: 24, thickness: 1),
                                  _buildSummaryRow(
                                    title: "Order ID".tr,
                                    value:
                                        controller.orderModel.value.id ?? 'N/A',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader("Location Details".tr),
                            _buildSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryRow(
                                    title: "Source".tr,
                                    value:
                                        "${controller.orderModel.value.sourceCity ?? 'N/A'}, ${controller.orderModel.value.sourceLocationName ?? 'N/A'}",
                                  ),
                                  const Divider(height: 24, thickness: 1),
                                  _buildSummaryRow(
                                    title: "Destination".tr,
                                    value:
                                        "${controller.orderModel.value.destinationCity ?? 'N/A'}, ${controller.orderModel.value.destinationLocationName ?? 'N/A'}",
                                  ),
                                  const Divider(height: 24, thickness: 1),
                                  _buildSummaryRow(
                                    title: "Distance".tr,
                                    value:
                                        "${controller.orderModel.value.distance ?? 'N/A'} ${controller.orderModel.value.distanceType ?? ''}",
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader("Parcel Images".tr),
                            _buildSectionCard(
                              child: controller
                                      .orderModel.value.parcelImage!.isEmpty
                                  ? Center(
                                      child: Text(
                                        "No Images Available".tr,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: AppColors.grey500,
                                        ),
                                      ),
                                    )
                                  : GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: controller
                                          .orderModel.value.parcelImage!.length,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: MediaQuery.of(context)
                                                    .orientation ==
                                                Orientation.portrait
                                            ? 2
                                            : 3,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                        childAspectRatio: 1,
                                      ),
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        return ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: controller.orderModel
                                                .value.parcelImage![index]
                                                .toString(),
                                            imageBuilder:
                                                (context, imageProvider) =>
                                                    Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                image: DecorationImage(
                                                  image: imageProvider,
                                                  fit: BoxFit.cover,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.08),
                                                    spreadRadius: 2,
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            placeholder: (context, url) =>
                                                const Center(
                                                    child:
                                                        CircularProgressIndicator()),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error),
                                            fit: BoxFit.cover,
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildMapSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: Responsive.height(35, context),
          child: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                controller.orderModel.value.sourceLocationLAtLng?.latitude ??
                    24.905702181412074,
                controller.orderModel.value.sourceLocationLAtLng?.longitude ??
                    67.07225639373064,
              ),
              zoom: 12,
            ),
            markers: _markers,
            polylines: _polylines,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: AppColors.darkBackground,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeChange.getThem()
            ? AppColors.darkContainerBackground
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        gradient: themeChange.getThem()
            ? null
            : LinearGradient(
                colors: [Colors.white, Colors.grey[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSummaryRow({
    required String title,
    required String value,
    Color? valueColor,
    TextStyle? titleStyle,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: titleStyle ??
                GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.grey500,
                ),
          ),
          Flexible(
            child: Text(
              value,
              style: valueStyle ??
                  GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: valueColor ?? AppColors.darkBackground,
                  ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
