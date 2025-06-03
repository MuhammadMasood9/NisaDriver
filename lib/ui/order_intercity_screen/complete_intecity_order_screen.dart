import 'package:clipboard/clipboard.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/order/complete_intercity_order_controller.dart';
import 'package:driver/model/tax_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_order_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:math';
import 'dart:ui';

class CompleteIntercityOrderScreen extends StatefulWidget {
  const CompleteIntercityOrderScreen({Key? key}) : super(key: key);

  @override
  State<CompleteIntercityOrderScreen> createState() =>
      _CompleteIntercityOrderScreenState();
}

class _CompleteIntercityOrderScreenState
    extends State<CompleteIntercityOrderScreen>
    with SingleTickerProviderStateMixin {
  final CompleteInterCityOrderController controller =
      Get.put(CompleteInterCityOrderController());
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

    print('Created ${newMarkers.length} markers');

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
            polylineId: const PolylineId('ride_route'),
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
        {
          "featureType": "all",
          "elementType": "labels",
          "stylers": [{"visibility": "on"}]
        },
        {
          "featureType": "road",
          "elementType": "geometry",
          "stylers": [{"color": "#e0e0e0"}]
        },
        {
          "featureType": "water",
          "elementType": "geometry",
          "stylers": [{"color": "#c4e4ff"}]
        },
        {
          "featureType": "poi",
          "elementType": "labels",
          "stylers": [{"visibility": "simplified"}]
        }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetX<CompleteInterCityOrderController>(
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: InkWell(
              onTap: () => Get.back(),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
            centerTitle: true,
            title: Text(
              "Ride Details".tr,
              style: AppTypography.appTitle(context),
            ),
          ),
          backgroundColor: AppColors.background,
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
                          spacing: 15,
                          children: [
                            _buildMapSection(context),
                            _buildSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 5,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    spacing: 5,
                                    children: [
                                      Text(
                                        "Ride ID".tr,
                                        style:
                                            AppTypography.headers(Get.context!),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          FlutterClipboard.copy(controller
                                                  .orderModel.value.id
                                                  .toString())
                                              .then((value) {
                                            ShowToastDialog.showToast(
                                                "OrderId copied".tr);
                                          });
                                        },
                                        child: DottedBorder(
                                          borderType: BorderType.RRect,
                                          radius: const Radius.circular(12),
                                          dashPattern: const [6, 6],
                                          color: AppColors.textFieldBorder,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            child: Text(
                                              "Copy".tr,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "#${controller.orderModel.value.id!.toUpperCase()}",
                                    style: AppTypography.label(Get.context!),
                                  ),
                                ],
                              ),
                            ),
                            _buildSectionHeader("User Details".tr),
                            _buildSectionCard(
                              child: UserDriverView(
                                userId: controller.orderModel.value.userId
                                    .toString(),
                                amount: controller.orderModel.value.finalRate
                                    .toString(),
                              ),
                            ),
                            _buildSectionHeader(
                                "Pickup and drop-off locations".tr),
                            _buildSectionCard(
                              child: LocationView(
                                sourceLocation: controller
                                    .orderModel.value.sourceLocationName
                                    .toString(),
                                destinationLocation: controller
                                    .orderModel.value.destinationLocationName
                                    .toString(),
                              ),
                            ),
                            _buildSectionHeader("Ride Status".tr),
                            _buildSectionCard(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    controller.orderModel.value.status
                                        .toString(),
                                    style:
                                        AppTypography.boldLabel(Get.context!),
                                  ),
                                  Text(
                                    Constant().formatTimestamp(controller
                                        .orderModel.value.createdDate),
                                    style: AppTypography.label(Get.context!),
                                  ),
                                ],
                              ),
                            ),
                            _buildSectionHeader("Booking Summary".tr),
                            _buildSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Booking Summary".tr,
                                    style:
                                        AppTypography.boldLabel(Get.context!),
                                  ),
                                  const Divider(height: 24, thickness: 1),
                                  _buildSummaryRow(
                                    title: "Ride Amount".tr,
                                    value: Constant.amountShow(
                                        amount: controller
                                            .orderModel.value.finalRate
                                            .toString()),
                                  ),
                                  const Divider(height: 24, thickness: 1),
                                  if (controller.orderModel.value.taxList !=
                                      null)
                                    ...controller.orderModel.value.taxList!
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      TaxModel taxModel = entry.value;
                                      return Column(
                                        children: [
                                          _buildSummaryRow(
                                            title:
                                                "${taxModel.title} (${taxModel.type == "fix" ? Constant.amountShow(amount: taxModel.tax) : "${taxModel.tax}%"})",
                                            value: Constant.amountShow(
                                              amount: Constant()
                                                  .calculateTax(
                                                    amount: (double.parse(
                                                                controller
                                                                    .orderModel
                                                                    .value
                                                                    .finalRate
                                                                    .toString()) -
                                                            double.parse(
                                                                controller
                                                                    .couponAmount
                                                                    .value
                                                                    .toString()))
                                                        .toString(),
                                                    taxModel: taxModel,
                                                  )
                                                  .toString(),
                                            ),
                                          ),
                                          const Divider(
                                              height: 24, thickness: 1),
                                        ],
                                      );
                                    }).toList(),
                                  _buildSummaryRow(
                                    title: "Discount".tr,
                                    value:
                                        "(-${controller.couponAmount.value == "0.0" ? Constant.amountShow(amount: "0.0") : Constant.amountShow(amount: controller.couponAmount.value)})",
                                    valueColor: Colors.red,
                                  ),
                                  const Divider(height: 24, thickness: 1),
                                  _buildSummaryRow(
                                    title: "Payable Amount".tr,
                                    value: Constant.amountShow(
                                        amount: controller
                                            .calculateAmount()
                                            .toString()),
                                    titleStyle: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14),
                                    valueStyle: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                            _buildSectionHeader("Admin Commission".tr),
                            _buildSectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Admin Commission".tr,
                                    style:
                                        AppTypography.boldLabel(Get.context!),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildSummaryRow(
                                    title: "Admin commission".tr,
                                    value:
                                        "(-${Constant.amountShow(amount: Constant.calculateAdminCommission(amount: (double.parse(controller.orderModel.value.finalRate.toString()) - double.parse(controller.couponAmount.value.toString())).toString(), adminCommission: controller.orderModel.value.adminCommission).toString())})",
                                    valueColor: Colors.red,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Note: Admin commission will be debited from your wallet balance. \nAdmin commission will apply on Ride Amount minus Discount (if applicable)."
                                        .tr,
                                    style:
                                        AppTypography.smBoldLabel(Get.context!)
                                            .copyWith(color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        title,
        style: AppTypography.headers(Get.context!),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:  Colors.white,
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
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
                AppTypography.boldLabel(Get.context!)
                    .copyWith(color: AppColors.grey500),
          ),
          Text(
            value,
            style: valueStyle ?? AppTypography.boldLabel(Get.context!),
          ),
        ],
      ),
    );
  }
}
