import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clipboard/clipboard.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/complete_order_controller.dart';
import 'package:driver/model/tax_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_order_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class CompleteOrderScreen extends StatefulWidget {
  const CompleteOrderScreen({Key? key}) : super(key: key);

  @override
  State<CompleteOrderScreen> createState() => _CompleteOrderScreenState();
}

class _CompleteOrderScreenState extends State<CompleteOrderScreen>
    with SingleTickerProviderStateMixin {
  final CompleteOrderController controller = Get.put(CompleteOrderController());

  // --- State Variables ---
  Set<Marker> _markers = {};
  List<LatLng> _polylineCoordinates = [];
  LatLngBounds? _bounds;
  String _routeDistance = '...';
  String _routeDuration = '...';
  bool _isLoadingRoute = true;
  late String mapStyle;

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  // --- Constants for consistent UI ---
  static const double _cardBorderRadius = 8.0;
  static const EdgeInsets _cardPadding = EdgeInsets.all(18.0);
  static const SizedBox _verticalSpacing = SizedBox(height: 16.0);

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
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

  void _loadMapStyle() {
    rootBundle.loadString('assets/map_style.json').then((value) {
      mapStyle = value;
    }).catchError((e) {
      mapStyle = ''; // Fallback to default map style
      debugPrint("Could not load map style from assets: $e");
    });
  }

  Future<void> initializeMapData() async {
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

    final iconStart = await getMarkerIcon('assets/images/green_mark.png', 70);
    final iconEnd = await getMarkerIcon('assets/images/red_mark.png', 70);

    _markers = {
      Marker(
        markerId: const MarkerId('source'),
        position: sourceLatLng,
        icon: iconStart,
        infoWindow:
            InfoWindow(title: 'Pickup: ${orderModel.sourceLocationName}'),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destinationLatLng,
        icon: iconEnd,
        infoWindow: InfoWindow(
            title: 'Drop-off: ${orderModel.destinationLocationName}'),
      ),
    };
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

    const String apiKey =
        'AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4'; // Replace with your API key
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
          ShowToastDialog.showToast("Could not fetch route details.");
        }
      } else {
        debugPrint("HTTP Error fetching directions: ${response.statusCode}");
        ShowToastDialog.showToast("Error connecting to routing service.");
      }
    } catch (e) {
      debugPrint("Exception fetching directions: $e");
      ShowToastDialog.showToast("An unexpected error occurred.");
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetX<CompleteOrderController>(
      builder: (controller) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.arrow_back_ios_new,
                    color: AppColors.primary, size: 20),
              ),
              onPressed: () => Get.back(),
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
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: _polylineCoordinates,
                          color: AppColors.primary,
                          width: 3,
                          patterns: [PatternItem.dash(15), PatternItem.gap(10)],
                        ),
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onMapCreated: (GoogleMapController mapController) async {
                        String style = await rootBundle
                            .loadString('assets/map_style.json');
                        mapController?.setMapStyle(style);
                        if (_bounds != null) {
                          mapController.animateCamera(
                              CameraUpdate.newLatLngBounds(_bounds!, 60));
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
                            color: AppColors.grey100,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                            boxShadow: [
                              BoxShadow(blurRadius: 20, color: Colors.black12),
                            ],
                          ),
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: Column(
                              children: [
                                _buildDragHandle(),
                                FadeTransition(
                                  opacity: _fadeAnimation!,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    child: Column(
                                      children: [
                                        _buildOrderIdSection(context),
                                        _verticalSpacing,
                                        _buildUserSection(context),
                                        _verticalSpacing,
                                        _buildLocationSection(context),
                                        _verticalSpacing,
                                        _buildBookingSummarySection(context),
                                        _verticalSpacing,
                                        _buildAdminCommissionSection(context),
                                        const SizedBox(height: 50),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
      width: 45,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
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
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
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
          const Icon(Icons.receipt_long_outlined,
              color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ride ID".tr,
                    style: AppTypography.appTitle(context)
                        .copyWith(color: AppColors.grey800)),
                const SizedBox(height: 2),
                Text(
                  "#${controller.orderModel.value.id!.toUpperCase()}",
                  style: AppTypography.caption(context)!
                      .copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              FlutterClipboard.copy(controller.orderModel.value.id.toString())
                  .then((_) => ShowToastDialog.showToast("Ride ID copied".tr));
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

  Widget _buildUserSection(BuildContext context) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(context, "User Details".tr),
          const Divider(
              color: AppColors.grey200, height: 1, indent: 5, endIndent: 5),
          const SizedBox(height: 10),
          UserDriverView(
            userId: controller.orderModel.value.userId.toString(),
            amount: controller.orderModel.value.finalRate.toString(),
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
          const SizedBox(height: 10),
          LocationView(
            sourceLocation:
                controller.orderModel.value.sourceLocationName.toString(),
            destinationLocation:
                controller.orderModel.value.destinationLocationName.toString(),
          ),
          const Divider(height: 12, color: AppColors.grey100),
          if (_isLoadingRoute)
            const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
          else
            Row(
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
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.appTitle(context)),
              Text(value,
                  style: AppTypography.caption(context)!
                      .copyWith(fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBookingSummarySection(BuildContext context) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(context, "Booking Summary".tr),
          const Divider(color: AppColors.grey200, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Payment Method".tr,
                  style: AppTypography.boldLabel(context)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  controller.orderModel.value.paymentType.toString(),
                  style: AppTypography.boldLabel(context)
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 1, color: AppColors.grey100),
          _buildSummaryRow(
            title: "Ride Amount".tr,
            value: Constant.amountShow(
                amount: controller.orderModel.value.finalRate.toString()),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            title: "Discount".tr,
            value:
                "(-${Constant.amountShow(amount: controller.couponAmount.value)})",
            valueStyle:
                AppTypography.boldLabel(context).copyWith(color: Colors.red),
          ),
          const SizedBox(height: 8),
          if (controller.orderModel.value.taxList != null)
            ...controller.orderModel.value.taxList!.map((taxModel) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: _buildSummaryRow(
                  title:
                      "${taxModel.title} (${taxModel.type == "fix" ? Constant.amountShow(amount: taxModel.tax) : "${taxModel.tax}%"})",
                  value: Constant.amountShow(
                    amount: Constant()
                        .calculateTax(
                          amount: (double.parse(controller
                                      .orderModel.value.finalRate
                                      .toString()) -
                                  double.parse(
                                      controller.couponAmount.value.toString()))
                              .toString(),
                          taxModel: taxModel,
                        )
                        .toString(),
                  ),
                ),
              );
            }).toList(),
          const Divider(height: 16, thickness: 1, color: AppColors.grey200),
          _buildSummaryRow(
            title: "Your Earning".tr,
            value: Constant.amountShow(
                amount: controller.calculateAmount().toString()),
            titleStyle: AppTypography.appTitle(context),
            valueStyle: AppTypography.appTitle(context).copyWith(
                color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCommissionSection(BuildContext context) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(context, "Admin Commission".tr),
          const Divider(color: AppColors.grey200, height: 1),
          const SizedBox(height: 10),
          _buildSummaryRow(
            title: "Admin commission".tr,
            value:
                "(-${Constant.amountShow(amount: Constant.calculateAdminCommission(amount: (double.parse(controller.orderModel.value.finalRate.toString()) - double.parse(controller.couponAmount.value.toString())).toString(), adminCommission: controller.orderModel.value.adminCommission).toString())})",
            valueStyle: AppTypography.boldLabel(context)
                .copyWith(color: Colors.red, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            "Note: Admin commission will be debited from your wallet balance. Admin commission will apply on Ride Amount minus Discount (if applicable)."
                .tr,
            style: AppTypography.label(context)!.copyWith(
                color: AppColors.primary.withOpacity(0.9), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String title,
    required String value,
    TextStyle? titleStyle,
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: titleStyle ??
                  AppTypography.boldLabel(context)
                      .copyWith(color: AppColors.grey500)),
          Text(value,
              style: valueStyle ??
                  AppTypography.boldLabel(context)
                      .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
