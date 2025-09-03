import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/scheduled_ride_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/order_screen/order_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ScheduledRideDetailsScreen extends StatefulWidget {
  final String scheduleId;

  const ScheduledRideDetailsScreen({super.key, required this.scheduleId});

  @override
  State<ScheduledRideDetailsScreen> createState() =>
      _ScheduledRideDetailsScreenState();
}

class _ScheduledRideDetailsScreenState extends State<ScheduledRideDetailsScreen>
    with TickerProviderStateMixin {
  // --- Map State ---
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLngBounds? _bounds;
  String _mapStyle = '';

  // --- Animation ---
  AnimationController? _animationController;
  Animation<double>? _panelAnimation;

  // --- Route Details State ---
  String _routeDistance = '...';
  String _routeDuration = '...';

  // --- UI Constants ---
  static const double _cardBorderRadius = 24.0;
  static const double _pagePadding = 20.0;
  static const SizedBox _verticalSpacing = SizedBox(height: 16.0);

  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 5,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _panelAnimation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOutCubic,
    );
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
    } catch (e) {
      debugPrint("Could not load map style: $e");
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(CollectionName.scheduledRides)
            .doc(widget.scheduleId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return _buildErrorState(
                'Something went wrong: ${snapshot.error}'.tr);
          if (snapshot.connectionState == ConnectionState.waiting)
            return _buildLoadingState();
          if (!snapshot.hasData || !snapshot.data!.exists)
            return _buildEmptyState('Schedule not found'.tr);

          final model = ScheduleRideModel.fromJson(
              snapshot.data!.data() as Map<String, dynamic>);

          if (_markers.isEmpty) {
            _initializeMapData(model);
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: _defaultCamera,
                markers: _markers,
                polylines: _polylines,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  if (_mapStyle.isNotEmpty)
                    _mapController?.setMapStyle(_mapStyle);
                  if (_bounds != null)
                    _mapController?.animateCamera(
                        CameraUpdate.newLatLngBounds(_bounds!, 60));
                },
              ),
              _buildDetailsPanel(context, model),
            ],
          );
        },
      ),
    );
  }

  // --- Main UI Components ---

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
      centerTitle: true,
    );
  }

  Widget _buildDetailsPanel(BuildContext context, ScheduleRideModel model) {
    _animationController?.forward();
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return FadeTransition(
          opacity: _panelAnimation!,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_cardBorderRadius)),
              boxShadow: [
                BoxShadow(
                    blurRadius: 20, color: Colors.black26, spreadRadius: 5)
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_cardBorderRadius)),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (model.userId != null)
                      _buildCustomerInfoCard(context, model.userId!),
                    _verticalSpacing,
                    _buildScheduleSummaryCard(context, model),
                    _verticalSpacing,
                    _buildRideLogbookSection(context, model),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Card Widgets ---

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardHeader(BuildContext context,
      {required String title, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(title, style: AppTypography.appTitle(context)),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard(BuildContext context, String customerId) {
    return _buildInfoCard(
      child: Column(
        children: [
          _buildCardHeader(context,
              title: "Customer Details".tr, icon: Icons.person_outline),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<UserModel?>(
              future: FireStoreUtils.getCustomer(customerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data == null)
                  return Text("Customer not found".tr);

                UserModel customer = snapshot.data!;
                return Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: customer.profilePic.toString(),
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                        placeholder: (c, u) =>
                            Container(color: Colors.grey.shade200),
                        errorWidget: (c, u, e) =>
                            const Icon(Icons.person, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.fullName ?? '',
                              style: AppTypography.boldLabel(context)
                                  .copyWith(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(customer.phoneNumber ?? '',
                              style: AppTypography.caption(context)
                                  .copyWith(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Constant.makePhoneCall(
                          customer.phoneNumber.toString()),
                      borderRadius: BorderRadius.circular(100),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.green.shade50,
                        child: Icon(Icons.call,
                            color: Colors.green.shade600, size: 20),
                      ),
                    )
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSummaryCard(
      BuildContext context, ScheduleRideModel model) {
    bool isScheduleActive = model.status == 'active';
    return _buildInfoCard(
      child: Column(
        children: [
          _buildCardHeader(context,
              title: "Schedule Summary".tr,
              icon: Icons.calendar_today_outlined),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInfoRow(
                    context,
                    Icons.payments_outlined,
                    "Weekly Payout".tr,
                    Constant.amountShow(amount: model.weeklyRate ?? '0'),
                    valueColor: AppColors.primary,
                    isLarge: true),
                const SizedBox(height: 12),
                _buildInfoRow(context, Icons.access_time_outlined,
                    "Daily Pickup".tr, model.scheduledTime ?? ''),
                const Divider(
                    height: 24, thickness: 1, color: AppColors.grey200),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFinanceGridItem(context,
                        title: "Distance", value: _routeDistance),
                    _buildFinanceGridItem(context,
                        title: "Est. Time", value: _routeDuration),
                  ],
                ),
                const Divider(
                    height: 24, thickness: 1, color: AppColors.grey200),
                _buildDaysRow(context, model.recursOnDays ?? []),
                if (isScheduleActive &&
                    model.currentWeekOtp != null &&
                    model.currentWeekOtp!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildOtpSection(context, model.currentWeekOtp!),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideLogbookSection(
      BuildContext context, ScheduleRideModel model) {
    return _buildInfoCard(
      child: Column(
        children: [
          _buildCardHeader(context,
              title: "This Week's Logbook".tr, icon: Icons.event_note_outlined),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(CollectionName.orders)
                  .where('scheduleId', isEqualTo: model.id)
                  .where('createdDate',
                      isGreaterThanOrEqualTo: _getStartOfWeek(DateTime.now()))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(
                      heightFactor: 3, child: CircularProgressIndicator());

                final spawnedOrders = <String, OrderModel>{};
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    OrderModel order =
                        OrderModel.fromJson(doc.data() as Map<String, dynamic>);
                    if (order.createdDate != null) {
                      String dateKey = DateFormat('yyyy-MM-dd')
                          .format(order.createdDate!.toDate());
                      spawnedOrders[dateKey] = order;
                    }
                  }
                }
                final scheduledDates = _getScheduledDatesForWeek(model);
                if (scheduledDates.isEmpty) {
                  return Center(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Text("No rides scheduled for this week.".tr,
                              style: AppTypography.caption(context))));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: scheduledDates.length,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final date = scheduledDates[index];
                    final dateKey = DateFormat('yyyy-MM-dd').format(date);
                    final orderForThisDate = spawnedOrders[dateKey];
                    return _buildLogbookRideTile(
                        context, date, orderForThisDate, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper and Utility Widgets ---
  Widget _buildLoadingState() =>
      const Center(child: CircularProgressIndicator());
  Widget _buildErrorState(String msg) => Center(child: Text(msg));
  Widget _buildEmptyState(String msg) => Center(child: Text(msg));

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String title, String value,
      {Color? valueColor, bool isLarge = false}) {
    return Row(children: [
      Icon(icon, color: Colors.grey.shade600, size: 20),
      const SizedBox(width: 12),
      Text(title, style: AppTypography.label(context)),
      const Spacer(),
      Text(value,
          style: (isLarge
                  ? AppTypography.boldLabel(context).copyWith(fontSize: 22)
                  : AppTypography.boldLabel(context))
              .copyWith(
                  color: valueColor ?? const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildFinanceGridItem(BuildContext context,
      {required String title, required String value}) {
    return Column(
      children: [
        Text(title.tr,
            style: AppTypography.caption(context)
                .copyWith(color: Colors.grey.shade500)),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.boldLabel(context)),
      ],
    );
  }

  Widget _buildDaysRow(BuildContext context, List<String> days) {
    final List<String> weekOrder = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final Map<String, String> dayAbbreviations = {
      'Monday': 'M',
      'Tuesday': 'T',
      'Wednesday': 'W',
      'Thursday': 'T',
      'Friday': 'F',
      'Saturday': 'S',
      'Sunday': 'S'
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("RECURRING ON".tr,
          style: AppTypography.caption(context).copyWith(
              color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weekOrder.map((dayName) {
          final isSelected = days.contains(dayName);
          return Container(
            width: 33,
            height: 33,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(dayAbbreviations[dayName]!,
                  style: AppTypography.boldLabel(context).copyWith(
                      color: isSelected ? Colors.white : Colors.grey.shade600)),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _buildOtpSection(BuildContext context, String otp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text("FIRST RIDE OTP".tr,
            style: AppTypography.caption(context).copyWith(
                color: AppColors.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(otp,
            style: AppTypography.headers(context).copyWith(
                color: AppColors.primary, letterSpacing: 8, fontSize: 32)),
        const SizedBox(height: 4),
        Text("Enter this OTP on the trip screen to start.".tr,
            textAlign: TextAlign.center,
            style: AppTypography.caption(context).copyWith(fontSize: 12)),
      ]),
    );
  }

  Widget _buildLogbookRideTile(BuildContext context, DateTime rideDate,
      OrderModel? dailyOrder, int index) {
    String dateDisplay = DateFormat('EEEE, MMM d').format(rideDate);
    String statusText;
    IconData statusIcon;
    Color iconColor;
    Widget? actionButton;

    if (dailyOrder != null) {
      switch (dailyOrder.status) {
        case Constant.rideComplete:
          statusIcon = Icons.check_circle;
          iconColor = Colors.green;
          statusText = "Completed".tr;
          actionButton = _buildActionButton(
              "Details", Colors.green, () => Get.to(() => OrderScreen()));
          break;
        case Constant.rideCanceled:
          statusIcon = Icons.cancel;
          iconColor = Colors.red;
          statusText = "Cancelled".tr;
          break;
        case Constant.rideActive:
          statusIcon = Icons.play_circle_fill;
          iconColor = AppColors.primary;
          statusText = "Ready to Start".tr;
          actionButton = _buildActionButton("Start Ride", AppColors.primary,
              () => Get.to(() => OrderScreen()));
          break;
        default:
          statusIcon = Icons.route;
          iconColor = Colors.orange;
          statusText = "In Progress".tr;
          actionButton = _buildActionButton(
              "View Ride", Colors.orange, () => Get.to(() => OrderScreen()));
      }
    } else {
      statusIcon = Icons.schedule;
      iconColor = Colors.grey.shade500;
      statusText = "Upcoming".tr;
    }

    return Row(children: [
      CircleAvatar(
          radius: 20,
          backgroundColor: iconColor.withValues(alpha: 0.1),
          child: Icon(statusIcon, color: iconColor, size: 20)),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(dateDisplay,
            style: AppTypography.boldLabel(context).copyWith(fontSize: 15)),
        const SizedBox(height: 2),
        Text(statusText,
            style: AppTypography.caption(context)
                .copyWith(color: iconColor, fontWeight: FontWeight.w500)),
      ])),
      if (actionButton != null) ...[const SizedBox(width: 12), actionButton],
    ]);
  }

  Widget _buildActionButton(String title, Color color, VoidCallback onPress) {
    return ElevatedButton(
      onPressed: onPress,
      style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      child: Text(title.tr,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  // --- Map and Data Logic ---
  Future<void> _initializeMapData(ScheduleRideModel model) async {
    final sourceLatLng = model.sourceLocationLAtLng;
    final destLatLng = model.destinationLocationLAtLng;

    if (sourceLatLng?.latitude == null || destLatLng?.latitude == null) return;

    final source = LatLng(sourceLatLng!.latitude!, sourceLatLng.longitude!);
    final dest = LatLng(destLatLng!.latitude!, destLatLng.longitude!);

    await _addMarkers(source, dest);
    await _getDirections(source, dest);

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

  Future<void> _addMarkers(LatLng source, LatLng dest) async {
    final iconStart = await _getMarkerIcon('assets/images/green_mark.png', 70);
    final iconEnd = await _getMarkerIcon('assets/images/red_mark.png', 70);
    _markers.add(Marker(
        markerId: const MarkerId('source'), position: source, icon: iconStart));
    _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: dest,
        icon: iconEnd));
  }

  Future<void> _getDirections(LatLng source, LatLng dest) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${dest.latitude},${dest.longitude}&key=${Constant.mapAPIKey}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];

          if (mounted) {
            setState(() {
              if (route['legs'] != null && (route['legs'] as List).isNotEmpty) {
                _routeDistance = route['legs'][0]['distance']['text'];
                _routeDuration = route['legs'][0]['duration']['text'];
              }

              final points = PolylinePoints()
                  .decodePolyline(route['overview_polyline']['points']);
              final polylineCoordinates =
                  points.map((p) => LatLng(p.latitude, p.longitude)).toList();
              _polylines.add(Polyline(
                polylineId: const PolylineId('route'),
                points: polylineCoordinates,
                color: AppColors.primary,
                width: 4,
              ));

              final boundsData = route['bounds'];
              _bounds = LatLngBounds(
                southwest: LatLng(boundsData['southwest']['lat'],
                    boundsData['southwest']['lng']),
                northeast: LatLng(boundsData['northeast']['lat'],
                    boundsData['northeast']['lng']),
              );

              if (_mapController != null && _bounds != null) {
                _mapController!
                    .animateCamera(CameraUpdate.newLatLngBounds(_bounds!, 60));
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Directions API error: $e");
    }
  }

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  List<DateTime> _getScheduledDatesForWeek(ScheduleRideModel model) {
    if (model.recursOnDays == null || model.recursOnDays!.isEmpty) return [];

    final List<DateTime> dates = [];
    DateTime today = DateTime.now();
    DateTime startOfWeek =
        _getStartOfWeek(DateTime(today.year, today.month, today.day));

    for (int i = 0; i < 7; i++) {
      DateTime dayToCheck = startOfWeek.add(Duration(days: i));
      final String dayName = DateFormat('EEEE').format(dayToCheck);
      if (model.recursOnDays!.contains(dayName)) {
        dates.add(dayToCheck);
      }
    }
    dates.sort((a, b) => a.compareTo(b));
    return dates;
  }
}
