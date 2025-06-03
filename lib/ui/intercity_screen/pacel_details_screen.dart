import 'package:cached_network_image/cached_network_image.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/parcel_details_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/widget/location_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:ui';

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
  Animation<Offset>? _slideAnimation;
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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOutCubic,
    ));
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

    print('Source: $sourceLatLng, Destination: $destinationLatLng');

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
      print('Custom marker icons loaded successfully');
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
        consumeTapEvents: true,
        onTap: () {
          print('Pickup marker tapped');
        },
      ),
      Marker(
        markerId: const MarkerId('dropoff_location'),
        position: destinationLatLng,
        icon: dropoffIcon,
        infoWindow: InfoWindow(
          title: 'Drop-off Location',
          snippet: orderModel.destinationLocationName ?? 'Destination location',
        ),
        consumeTapEvents: true,
        onTap: () {
          print('Dropoff marker tapped');
        },
      ),
    };

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }

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

        if (mounted) {
          setState(() {
            _polylines = newPolylines;
          });
        }
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

      PolylineResult result = (await polylinePoints.getRouteBetweenCoordinates(
        request: request,
        googleApiKey: 'AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4',
      )) as PolylineResult;

      if (result.points.isNotEmpty) {
        polylineCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
        print('Polyline points loaded: ${polylineCoordinates.length} points');
      } else {
        print('No polyline results found, using straight line');
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
    return Obx(() {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildSimpleAppBar(context),
        body: controller.isLoading.value
            ? Constant.loader(context)
            : FadeTransition(
                opacity: _fadeAnimation!,
                child: SlideTransition(
                  position: _slideAnimation!,
                  child: SingleChildScrollView(
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 15,
                          children: [
                            _buildMapSection(context),
                            _buildLocationTimeline(context),
                            _buildParcelInfo(context),
                            _buildImageGallery(context),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      );
    });
  }

  PreferredSizeWidget _buildSimpleAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
        title: Text(
          "Parcel Details".tr,
          style: AppTypography.appTitle(context),
        ),
      ),
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
          height: Responsive.height(30, context),
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
            onTap: (LatLng location) {
              print('Map tapped at: $location');
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLocationTimeline(
      BuildContext context) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Text(
            "Route Information".tr,
            style: AppTypography.headers(Get.context!),
          ),
          LocationView(
            sourceLocation:
                controller.orderModel.value.sourceLocationName?.toString() ??
                    'N/A',
            destinationLocation:
                controller.orderModel.value.destinationCity?.toString() ??
                    'N/A',
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  spreadRadius: 2,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.straighten_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  "Distance: ${controller.orderModel.value.distance ?? 'N/A'} ${controller.orderModel.value.distanceType ?? ''}",
                  style: AppTypography.label(Get.context!)
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelInfo(BuildContext context) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Text(
            "Order Information".tr,
            style: AppTypography.headers(Get.context!),
          ),
          _buildInfoRow(
            icon: Icons.confirmation_number_rounded,
            title: "Order ID".tr,
            value: controller.orderModel.value.id?.toString() ?? 'N/A',
            
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,

  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.label(Get.context!)
                      .copyWith(color: AppColors.grey500),
                ),
                Text(
                  value,
                  style: AppTypography.boldLabel(Get.context!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(
      BuildContext context) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Parcel Images".tr,
                  style: AppTypography.headers(Get.context!),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${controller.orderModel.value.parcelImage?.length ?? 0}",
                  style: AppTypography.label(Get.context!)
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          controller.orderModel.value.parcelImage?.isEmpty ?? true
              ? Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color:  Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        spreadRadius: 2,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_rounded,
                          size: 32,
                          color: AppColors.grey500,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "No Images Available".tr,
                          style: AppTypography.label(Get.context!)
                              .copyWith(color: AppColors.grey500),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.orderModel.value.parcelImage!.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).orientation ==
                            Orientation.portrait
                        ? 2
                        : 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return Hero(
                      tag: 'parcel_image_$index',
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              spreadRadius: 2,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: controller
                                .orderModel.value.parcelImage![index]
                                .toString(),
                            imageBuilder: (context, imageProvider) => Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: imageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    // Add image preview functionality
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.1),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            placeholder: (context, url) => Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[100],
                              child: Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: AppColors.grey500,
                                  size: 32,
                                ),
                              ),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        gradient:  LinearGradient(
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
}
