import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clipboard/clipboard.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/order/complete_intercity_order_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/widget/user_order_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class CompleteIntercityOrderScreen extends StatefulWidget {
  const CompleteIntercityOrderScreen({super.key});

  @override
  State<CompleteIntercityOrderScreen> createState() =>
      _CompleteIntercityOrderScreenState();
}

class _CompleteIntercityOrderScreenState
    extends State<CompleteIntercityOrderScreen>
    with SingleTickerProviderStateMixin {
  final CompleteInterCityOrderController controller =
      Get.put(CompleteInterCityOrderController());

  // --- UI Constants ---
  static const double _pagePadding = 16.0;
  static const double _cardBorderRadius = 20.0;
  static const EdgeInsets _cardContentPadding = EdgeInsets.all(16.0);
  static const SizedBox _verticalSpacing = SizedBox(height: 12.0);

  // --- State Variables ---
  final Set<Marker> _markers = {};
  final List<LatLng> _polylineCoordinates = [];
  LatLngBounds? _bounds;
  String _routeDuration = '...';
  String _mapStyle = '';
  AnimationController? _animationController;
  Animation<double>? _panelAnimation;

  static const CameraPosition _defaultCameraPosition = CameraPosition(
    target: LatLng(24.8607, 67.0011), // Default to a central location
    zoom: 11,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _panelAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadMapStyle();
      await initializeMapData();
      _animationController?.forward();
    });
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
    } catch (e) {
      debugPrint("Could not load map style: $e");
    }
  }

  Future<void> initializeMapData() async {
    if (controller.orderModel.value.id == null) return;
    await _addMarkers();
    await _getDirectionsAndRouteInfo();
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _getMarkerIcon(String path, int width) async {
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
    final order = controller.orderModel.value;
    if (order.sourceLocationLAtLng?.latitude == null ||
        order.sourceLocationLAtLng?.longitude == null ||
        order.destinationLocationLAtLng?.latitude == null ||
        order.destinationLocationLAtLng?.longitude == null) {
      debugPrint("Cannot add markers: Location data is incomplete.");
      return;
    }
    final sourceLatLng = LatLng(order.sourceLocationLAtLng!.latitude!,
        order.sourceLocationLAtLng!.longitude!);
    final destLatLng = LatLng(order.destinationLocationLAtLng!.latitude!,
        order.destinationLocationLAtLng!.longitude!);
    final iconStart = await _getMarkerIcon('assets/images/green_mark.png', 50);
    final iconEnd = await _getMarkerIcon('assets/images/red_mark.png', 50);
    _markers.add(Marker(
        markerId: const MarkerId('source'),
        position: sourceLatLng,
        icon: iconStart));
    _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destLatLng,
        icon: iconEnd));
  }

  Future<void> _getDirectionsAndRouteInfo() async {
    final order = controller.orderModel.value;
    if (order.sourceLocationLAtLng?.latitude == null ||
        order.sourceLocationLAtLng?.longitude == null ||
        order.destinationLocationLAtLng?.latitude == null ||
        order.destinationLocationLAtLng?.longitude == null) {
      debugPrint("Cannot get directions: Location data is incomplete.");
      return;
    }
    final source = LatLng(order.sourceLocationLAtLng!.latitude!,
        order.sourceLocationLAtLng!.longitude!);
    final dest = LatLng(order.destinationLocationLAtLng!.latitude!,
        order.destinationLocationLAtLng!.longitude!);
    String apiKey = Constant.mapAPIKey;
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${dest.latitude},${dest.longitude}&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          if (mounted) {
            setState(() {
              _routeDuration = route['legs'][0]['duration']['text'];
              final points = PolylinePoints()
                  .decodePolyline(route['overview_polyline']['points']);
              _polylineCoordinates.addAll(
                  points.map((p) => LatLng(p.latitude, p.longitude)).toList());
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
      debugPrint("Directions API error: $e");
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetX<CompleteInterCityOrderController>(builder: (controller) {
      final sourceLocation = controller.orderModel.value.sourceLocationLAtLng;
      final initialCameraPosition = (sourceLocation?.latitude != null &&
              sourceLocation?.longitude != null)
          ? CameraPosition(
              target:
                  LatLng(sourceLocation!.latitude!, sourceLocation.longitude!),
              zoom: 12,
            )
          : _defaultCameraPosition;
      return Scaffold(
        backgroundColor: AppColors.background,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: AppColors.background,
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
        ),
        body: controller.isLoading.value
            ? Constant.loader(context)
            : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: initialCameraPosition,
                    markers: _markers,
                    polylines: {
                      if (_polylineCoordinates.isNotEmpty)
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: _polylineCoordinates,
                          color: AppColors.primary,
                          width: 2,
                          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
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
                  _buildLocationHeaderCard(context),
                  _buildSummaryPanel(context),
                ],
              ),
      );
    });
  }

  Widget _buildLocationHeaderCard(BuildContext context) {
    if (_panelAnimation == null) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).padding.top + kToolbarHeight + 10,
      left: _pagePadding,
      right: _pagePadding,
      child: FadeTransition(
        opacity: _panelAnimation!,
        child: Container(
          padding: _cardContentPadding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLocationRow(
                icon: Icons.trip_origin,
                iconColor: AppColors.primary,
                title: "Pickup point",
                subtitle:
                    controller.orderModel.value.sourceLocationName ?? 'N/A',
              ),
              const Divider(height: 20),
              _buildLocationRow(
                icon: Icons.location_on,
                iconColor: Colors.red.shade700,
                title: "Destination",
                subtitle: controller.orderModel.value.destinationLocationName ??
                    'N/A',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow(
      {required IconData icon,
      required Color iconColor,
      required String title,
      required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.tr, style: AppTypography.caption(context)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.boldLabel(context).copyWith(height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryPanel(BuildContext context) {
    if (_panelAnimation == null) return const SizedBox.shrink();

    final double rideFare = _parseAmount(controller.orderModel.value.finalRate);
    final double couponAmount = _parseAmount(controller.couponAmount.value);
    final double rideFareAfterDiscount = rideFare - couponAmount;

    return DraggableScrollableSheet(
        initialChildSize: 0.33,
        minChildSize: 0.32,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return FadeTransition(
            opacity: _panelAnimation!,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.grey75,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_cardBorderRadius)),
                boxShadow: [
                  BoxShadow(
                      blurRadius: 20, color: Colors.black12, spreadRadius: 5)
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_cardBorderRadius)),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      _buildOrderIdSection(context),
                      _verticalSpacing,
                      _buildUserSection(context),
                      _verticalSpacing,
                      _buildFareDetailsSection(context, rideFare, couponAmount,
                          rideFareAfterDiscount),
                      _verticalSpacing,
                      _buildTotalEarningSection(context),
                      _verticalSpacing,
                      ElevatedButton(
                        onPressed: () => Get.back(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                        ),
                        child: Text("Done".tr,
                            style: AppTypography.appTitle(context)
                                .copyWith(color: Colors.white)),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      padding: _cardContentPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
          const Icon(Icons.receipt_long_outlined,
              color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ride ID".tr,
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
          const Divider(height: 1),
          const SizedBox(height: 12),
          UserDriverView(
            userId: controller.orderModel.value.userId?.toString() ?? '',
            amount:
                _parseAmount(controller.orderModel.value.finalRate).toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildFareDetailsSection(BuildContext context, double rideFare,
      double couponAmount, double rideFareAfterDiscount) {
    return _buildInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(context, "Fare Details".tr),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFinanceGridItem(context,
                  title: "Distance",
                  value:
                      "${_parseAmount(controller.orderModel.value.distance).toStringAsFixed(2)} ${controller.orderModel.value.distanceType}" ??
                          'N/A',
                  valueColor: Colors.black),
              _buildFinanceGridItem(context,
                  title: "Payment",
                  value: controller.orderModel.value.paymentType ?? 'N/A'),
              _buildFinanceGridItem(context,
                  title: "Travel Time", value: _routeDuration),
            ],
          ),
          const Divider(height: 24),
          _buildSummaryRow(context,
              title: "Ride Fare",
              value: Constant.amountShow(amount: rideFare.toString())),
          _buildSummaryRow(context,
              title: "Discount",
              value:
                  "(-${Constant.amountShow(amount: couponAmount.toString())})",
              valueColor: Colors.green),
          if (controller.orderModel.value.taxList != null)
            ...controller.orderModel.value.taxList!
                .map((tax) => _buildSummaryRow(
                      context,
                      title:
                          "${tax.title} (${tax.type == "fix" ? Constant.amountShow(amount: tax.tax) : "${tax.tax}%"})",
                      value: Constant.amountShow(
                        amount: Constant()
                            .calculateTax(
                                amount: rideFareAfterDiscount.toString(),
                                taxModel: tax)
                            .toString(),
                      ),
                    )),
          _buildSummaryRow(
            context,
            title: "Admin Commission",
            value:
                "(-${Constant.amountShow(amount: Constant.calculateAdminCommission(amount: rideFareAfterDiscount.toString(), adminCommission: controller.orderModel.value.adminCommission).toString())})",
            valueColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalEarningSection(BuildContext context) {
    return _buildInfoCard(
      child: Column(
        children: [
          _buildSummaryRow(context,
              title: "Total Earning".tr,
              value: Constant.amountShow(
                  amount: controller.calculateAmount().toString()),
              isLarge: true),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10)),
            child: Text(
                "Note: Admin commission will be debited from your wallet balance."
                    .tr,
                textAlign: TextAlign.center,
                style: AppTypography.caption(context)
                    .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceGridItem(BuildContext context,
      {required String title, required String value, Color? valueColor}) {
    return Column(
      children: [
        Text(title.tr, style: AppTypography.caption(context)),
        const SizedBox(height: 4),
        Text(value,
            style:
                AppTypography.boldLabel(context).copyWith(color: valueColor)),
      ],
    );
  }

  Widget _buildSummaryRow(BuildContext context,
      {required String title,
      required String value,
      Color? valueColor,
      bool isLarge = false}) {
    final titleStyle = isLarge
        ? AppTypography.appTitle(context).copyWith(fontWeight: FontWeight.w600)
        : AppTypography.label(context);
    final valueStyle = isLarge
        ? AppTypography.appTitle(context)
            .copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)
        : AppTypography.boldLabel(context).copyWith(color: valueColor);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.tr, style: titleStyle),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
