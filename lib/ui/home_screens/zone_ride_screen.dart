import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/home_screens/order_map_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// NEW: Import for reverse geocoding to get addresses from coordinates
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~ ENHANCED: ROUTE MATCHING RIDE FINDER ~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

// To better reflect the new functionality, this screen is renamed.
class RouteMatchingScreen extends StatefulWidget {
  const RouteMatchingScreen({super.key});

  @override
  State<RouteMatchingScreen> createState() => _RouteMatchingScreenState();
}

// Enum to manage the multi-step UI flow
enum RouteSetupState { none, originSet, destinationSet, searching, rideFound }

class _RouteMatchingScreenState extends State<RouteMatchingScreen> {
  final HomeController controller = Get.find<HomeController>();
  GoogleMapController? _mapController;
  final Set<Circle> _circles = {};

  // --- State for the new Route Matching logic ---
  RouteSetupState _currentState = RouteSetupState.none;
  bool _isFetchingRoute = false;

  // Driver's intended route
  LatLng? _driverOrigin;
  LatLng? _driverDestination;
  String _driverOriginAddress = '';
  String _driverDestinationAddress = '';
  List<LatLng> _driverRoutePoints = [];

  // User's matched ride
  OrderModel? _matchedRide;

  // Map elements
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Streams and Subscriptions
  Stream<List<OrderModel>>? _allNewOrdersBroadcastStream;
  StreamSubscription? _rideSearchSubscription;
  final Set<String> _shownRidePopups = {};

  // For fetching decoded polylines from Google Directions API
  final PolylinePoints _polylinePoints = PolylinePoints();
  // TODO: IMPORTANT! Add your Google Maps API Key with "Directions API" and "Geocoding API" enabled.
  final String _googleApiKey = "AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4";

  // --- NEW: User-configurable matching tolerance ---
  double _matchingToleranceMeters =
      1500; // Default 1.5km, can be changed by user

  // Custom marker icons
  BitmapDescriptor _originIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _destinationIcon = BitmapDescriptor.defaultMarker;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
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
    _mapController?.dispose();
    _rideSearchSubscription?.cancel();
    super.dispose();
  }

  // --- Core UI and State Management ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildTopInstructionPanel(),
          _buildFloatingActionButtons(),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  void _handleMapTap(LatLng position) {
    if (_currentState == RouteSetupState.searching ||
        _currentState == RouteSetupState.rideFound) return;

    if (_currentState == RouteSetupState.none) {
      _setOrigin(position);
    } else if (_currentState == RouteSetupState.originSet) {
      _setDestination(position);
    }
  }

  // --- Route Setup and Editing Logic ---

  Future<void> _setOrigin(LatLng position) async {
    setState(() {
      _driverOrigin = position;
      _driverOriginAddress = 'Loading address...'.tr;
      _currentState = RouteSetupState.originSet;
      _markers.add(Marker(
        markerId: const MarkerId('driver_origin'),
        position: _driverOrigin!,
        icon: _originIcon,
        infoWindow: InfoWindow(title: 'My Start'.tr),
      ));
    });
    _updateMarkerAddress(position, isOrigin: true);
  }

  Future<void> _setDestination(LatLng position) async {
    setState(() {
      _driverDestination = position;
      _driverDestinationAddress = 'Loading address...'.tr;
      _markers.add(Marker(
        markerId: const MarkerId('driver_destination'),
        position: _driverDestination!,
        icon: _destinationIcon,
        infoWindow: InfoWindow(title: 'My Destination'.tr),
      ));
    });
    await _drawDriverRoute();
    if (mounted && _driverRoutePoints.isNotEmpty) {
      setState(() => _currentState = RouteSetupState.destinationSet);
    }
    _updateMarkerAddress(position, isOrigin: false);
  }

  void _clearPoint({required bool isOrigin}) {
    setState(() {
      if (isOrigin) {
        // Clearing origin resets everything
        _resetRoute();
      } else {
        // Clearing destination just goes back one step
        _driverDestination = null;
        _driverDestinationAddress = '';
        _markers.removeWhere((m) => m.markerId.value == 'driver_destination');
        _polylines.removeWhere((p) => p.polylineId.value == 'driver_route');
        _driverRoutePoints.clear();
        _circles.clear();
        _currentState = RouteSetupState.originSet;
      }
    });
  }

  Future<void> _updateMarkerAddress(LatLng position,
      {required bool isOrigin}) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final placemark = placemarks.first;
        final address = '${placemark.street}, ${placemark.locality}';
        setState(() {
          if (isOrigin) {
            _driverOriginAddress = address;
          } else {
            _driverDestinationAddress = address;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final errorMsg = 'Could not get address'.tr;
          if (isOrigin) {
            _driverOriginAddress = errorMsg;
          } else {
            _driverDestinationAddress = errorMsg;
          }
        });
      }
      debugPrint("Error with reverse geocoding: $e");
    }
  }

  // --- Ride Searching and Matching Logic ---

  void _startSearchingForRides() {
    if (_driverRoutePoints.isEmpty || _allNewOrdersBroadcastStream == null) {
      Get.snackbar('Error'.tr, 'Cannot start search without a valid route.'.tr);
      return;
    }
    setState(() => _currentState = RouteSetupState.searching);
    _rideSearchSubscription = _allNewOrdersBroadcastStream!.listen((orders) {
      if (!mounted || _currentState != RouteSetupState.searching) return;
      final potentialRide = orders.firstWhereOrNull((order) {
        if (_shownRidePopups.contains(order.id) ||
            order.sourceLocationLAtLng == null ||
            order.destinationLocationLAtLng == null) {
          return false;
        }
        return _isRouteMatch(order);
      });
      if (potentialRide != null) {
        _rideSearchSubscription?.cancel();
        _shownRidePopups.add(potentialRide.id!);
        _showMatchedRideOnMap(potentialRide);
      }
    });
  }

  bool _isRouteMatch(OrderModel order) {
    final userPickup = LatLng(order.sourceLocationLAtLng!.latitude!,
        order.sourceLocationLAtLng!.longitude!);
    final userDropoff = LatLng(order.destinationLocationLAtLng!.latitude!,
        order.destinationLocationLAtLng!.longitude!);

    // UPDATED: Use the dynamic tolerance value
    final isPickupOnPath = _isLocationOnPath(
        userPickup, _driverRoutePoints, _matchingToleranceMeters);
    final isDropoffOnPath = _isLocationOnPath(
        userDropoff, _driverRoutePoints, _matchingToleranceMeters);

    return isPickupOnPath && isDropoffOnPath;
  }

  void _stopSearching() {
    _rideSearchSubscription?.cancel();
    setState(() => _currentState = RouteSetupState.destinationSet);
  }

  void _resetRoute() {
    _rideSearchSubscription?.cancel();
    setState(() {
      _currentState = RouteSetupState.none;
      _driverOrigin = null;
      _driverDestination = null;
      _driverOriginAddress = '';
      _driverDestinationAddress = '';
      _matchedRide = null;
      _driverRoutePoints.clear();
      _markers.clear();
      _circles.clear();
      _polylines.clear();
    });
  }

  // --- Map Drawing and Updates ---

  Future<void> _drawDriverRoute() async {
    if (_driverOrigin == null || _driverDestination == null) return;
    setState(() => _isFetchingRoute = true);

    _polylines.removeWhere((p) => p.polylineId.value == 'driver_route');
    _circles.clear();

    try {
      final points =
          await _getRouteCoordinates(_driverOrigin!, _driverDestination!);
      if (points.isNotEmpty && mounted) {
        setState(() {
          _driverRoutePoints = points;
          _polylines.add(Polyline(
              polylineId: const PolylineId('driver_route'),
              points: _driverRoutePoints,
              color: AppColors.primary,
              width: 3,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              patterns: <PatternItem>[
                PatternItem.dash(20),
                PatternItem.gap(10)
              ]));

          // Draw the tolerance zone corridor using the dynamic radius
          for (int i = 0; i < _driverRoutePoints.length; i++) {
            _circles.add(Circle(
              circleId: CircleId('tolerance_circle_$i'),
              center: _driverRoutePoints[i],
              radius: _matchingToleranceMeters, // UPDATED
              fillColor: AppColors.primary.withOpacity(0.15),
              strokeWidth: 1,
              strokeColor: AppColors.primary.withOpacity(0.3),
            ));
          }

          final bounds =
              _boundsFromLatLngList([_driverOrigin!, _driverDestination!]);
          _mapController
              ?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
        });
      }
    } finally {
      if (mounted) setState(() => _isFetchingRoute = false);
    }
  }

  Future<void> _showMatchedRideOnMap(OrderModel ride) async {
    final userPickup = LatLng(ride.sourceLocationLAtLng!.latitude!,
        ride.sourceLocationLAtLng!.longitude!);
    final userDropoff = LatLng(ride.destinationLocationLAtLng!.latitude!,
        ride.destinationLocationLAtLng!.longitude!);

    _markers.add(Marker(
      markerId: const MarkerId('user_pickup'),
      position: userPickup,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(title: 'Passenger Pickup'.tr),
    ));
    _markers.add(Marker(
      markerId: const MarkerId('user_dropoff'),
      position: userDropoff,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      infoWindow: InfoWindow(title: 'Passenger Drop-off'.tr),
    ));

    final userRoutePoints = await _getRouteCoordinates(userPickup, userDropoff);
    if (userRoutePoints.isNotEmpty) {
      _polylines.add(Polyline(
          polylineId: const PolylineId('user_route'),
          points: userRoutePoints,
          color: AppColors.darkBackground,
          width: 3,
          patterns: <PatternItem>[PatternItem.dash(20), PatternItem.gap(10)]));
    }

    final bounds = _boundsFromLatLngList(
        [_driverOrigin!, _driverDestination!, userPickup, userDropoff]);
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));

    setState(() {
      _matchedRide = ride;
      _currentState = RouteSetupState.rideFound;
    });
  }

  void _dismissMatchedRide() {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value.startsWith('user_'));
      _polylines.removeWhere((p) => p.polylineId.value == 'user_route');
      _matchedRide = null;
      _startSearchingForRides(); // Go back to searching
    });
  }

  Future<List<LatLng>> _getRouteCoordinates(
      LatLng origin, LatLng destination) async {
    if (_googleApiKey.contains("AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4")) {
      debugPrint(
          "Directions API Skipped: Please add your Google Maps API key.");
      return [origin, destination]; // Fallback to a straight line
    }
    try {
      PolylineResult result = await _polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
        googleApiKey: _googleApiKey,
      );
      if (result.points.isNotEmpty) {
        return result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      }
    } catch (e) {
      debugPrint("Error fetching polyline: $e");
    }
    return [origin, destination]; // Fallback on error
  }

  // --- Widget Builders ---

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(Constant.currentLocation?.latitude ?? 37.7749,
            Constant.currentLocation?.longitude ?? -122.4194),
        zoom: 12.5,
      ),
      onMapCreated: (mapController) async {
        _mapController = mapController;
        String style = await rootBundle.loadString('assets/map_style.json');
        _mapController?.setMapStyle(style);
      },
      onTap: _handleMapTap,
      markers: _markers,
      polylines: _polylines,
      circles: _circles,
      myLocationButtonEnabled: false,
      myLocationEnabled: true,
      zoomControlsEnabled: false,
    );
  }

  Widget _buildTopInstructionPanel() {
    String instruction;
    Color bgColor;
    IconData icon;
    switch (_currentState) {
      case RouteSetupState.none:
        instruction = "Tap map to set your start point".tr;
        bgColor = AppColors.primary;
        icon = Icons.touch_app_outlined;
        break;
      case RouteSetupState.originSet:
        instruction = "Tap map to set your destination".tr;
        bgColor = AppColors.primary;
        icon = Icons.touch_app;
        break;
      case RouteSetupState.destinationSet:
        instruction = "Confirm your route to find rides".tr;
        bgColor = Colors.blue.shade600;
        icon = Icons.check_circle_outline;
        break;
      case RouteSetupState.searching:
        instruction = "Searching for matching rides...".tr;
        bgColor = Colors.green.shade600;
        icon = Icons.radar;
        break;
      case RouteSetupState.rideFound:
        instruction = "Matching Ride Found!".tr;
        bgColor = AppColors.primary;
        icon = Icons.local_taxi;
        break;
    }
    return Positioned(
      top: MediaQuery.of(context).padding.top + 15,
      left: 70,
      right: 70,
      child: Material(
        elevation: 8.0,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  instruction,
                  style: AppTypography.boldLabel(context)
                      .copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 15,
      right: 15,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FloatingActionButton.small(
            heroTag: 'back_btn',
            onPressed: () => Get.back(),
            backgroundColor: Colors.white,
            child: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
          FloatingActionButton.small(
            heroTag: 'location_btn',
            onPressed: () =>
                _mapController?.animateCamera(CameraUpdate.newLatLng(
              LatLng(Constant.currentLocation!.latitude!,
                  Constant.currentLocation!.longitude!),
            )),
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    bool showPanel;
    Widget panelContent;

    switch (_currentState) {
      case RouteSetupState.none:
      case RouteSetupState.originSet:
        showPanel = true;
        panelContent = _buildRouteSetupPanel();
        break;
      case RouteSetupState.destinationSet:
      case RouteSetupState.searching:
        showPanel = true;
        panelContent = _buildRouteConfirmationPanel();
        break;
      case RouteSetupState.rideFound:
        showPanel = true;
        panelContent = _buildMatchedRidePopup(_matchedRide!);
        break;
      default:
        showPanel = false;
        panelContent = const SizedBox.shrink();
    }
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      bottom: showPanel ? 0 : -350, // Increased height to hide taller panels
      left: 0,
      right: 0,
      child: panelContent,
    );
  }

  // --- NEW: A dedicated panel for setting up the route ---
  Widget _buildRouteSetupPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: _panelBoxDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationRow(
            icon: Icons.trip_origin,
            iconColor: Colors.green,
            text: _driverOriginAddress.isEmpty
                ? 'Tap map to set start point'.tr
                : _driverOriginAddress,
            onClear: _driverOrigin == null
                ? null
                : () => _clearPoint(isOrigin: true),
          ),
          const Divider(height: 20),
          _buildLocationRow(
            icon: Icons.flag,
            iconColor: Colors.red,
            text: _driverDestinationAddress.isEmpty
                ? 'Tap map to set destination'.tr
                : _driverDestinationAddress,
            onClear: _driverDestination == null
                ? null
                : () => _clearPoint(isOrigin: false),
            isLoading: _isFetchingRoute,
          ),
          const SizedBox(height: 16),

          // --- NEW SLIDER WIDGET FOR TOLERANCE ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Matching Radius:".tr,
                    style: AppTypography.headers(context)),
                Text(
                  _formatToleranceLabel(_matchingToleranceMeters),
                  style: AppTypography.headers(context).copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Slider(
            value: _matchingToleranceMeters,
            min: 100,
            max: 3000,
            divisions: 29, // Creates steps of 100m
            label: _formatToleranceLabel(_matchingToleranceMeters),
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primary.withOpacity(0.3),
            onChanged: (double value) {
              setState(() {
                // Snap to nearest 100m for cleaner values
                _matchingToleranceMeters = (value / 100).round() * 100.0;
              });
              // Redraw the corridor if the route is already defined
              if (_driverRoutePoints.isNotEmpty) {
                _drawDriverRoute();
              }
            },
          ),
          // --- END NEW SLIDER WIDGET ---

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text("Reset Route".tr),
              onPressed: _resetRoute,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLocationRow(
      {required IconData icon,
      required Color iconColor,
      required String text,
      required VoidCallback? onClear,
      bool isLoading = false}) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color:
                  text.contains('...') ? Colors.grey.shade600 : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        if (isLoading)
          const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3))
        else
          SizedBox(
            width: 32,
            height: 32,
            child: onClear == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: onClear,
                    color: Colors.grey.shade500),
          )
      ],
    );
  }

  Widget _buildRouteConfirmationPanel() {
    bool isSearching = _currentState == RouteSetupState.searching;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: _panelBoxDecoration(),
      child: Row(
        children: [
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: isSearching ? null : _resetRoute,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              child: Icon(Icons.refresh, color: Colors.grey.shade700, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                icon: Icon(isSearching ? Icons.stop_circle : Icons.search),
                label: Text(
                  isSearching ? "Stop Searching".tr : "Find Rides".tr,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
                onPressed:
                    isSearching ? _stopSearching : _startSearchingForRides,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSearching ? Colors.red.shade600 : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedRidePopup(OrderModel order) => Container(
        decoration: _panelBoxDecoration(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserView(
                  userId: order.userId,
                  amount: order.offerRate,
                  distance: order.distance,
                  distanceType: order.distanceType),
              const Divider(height: 24, thickness: 1),
              LocationView(
                  sourceLocation: order.sourceLocationName.toString(),
                  destinationLocation:
                      order.destinationLocationName.toString()),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _dismissMatchedRide,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade800,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text("Dismiss".tr,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.to(() => const OrderMapScreen(),
                            arguments: {"orderModel": order.id.toString()});
                        _resetRoute();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text("View & Accept".tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  // --- HELPER FUNCTIONS ---

  BoxDecoration _panelBoxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 5)
      ],
    );
  }

  // NEW: Helper to format the slider label
  String _formatToleranceLabel(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km'.tr;
    }
  }

  Future<void> _loadCustomMarkers() async {
    try {
      _originIcon = await _bitmapDescriptorFromAsset(
          'assets/images/marker_origin.png', 100);
      _destinationIcon = await _bitmapDescriptorFromAsset(
          'assets/images/marker_destination.png', 100);
    } catch (e) {
      debugPrint("Custom markers not found, using defaults. Error: $e");
      _originIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      _destinationIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromAsset(
      String assetName, int width) async {
    final ByteData data = await rootBundle.load(assetName);
    final ui.Codec codec = await ui
        .instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    final ui.FrameInfo fi = await codec.getNextFrame();
    return BitmapDescriptor.fromBytes(
        (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List());
  }

  bool _isLocationOnPath(
      LatLng point, List<LatLng> polyline, double tolerance) {
    if (polyline.isEmpty) return false;
    for (int i = 0; i < polyline.length - 1; i++) {
      if (_isLocationOnSegment(
          point, polyline[i], polyline[i + 1], tolerance)) {
        return true;
      }
    }
    return false;
  }

  bool _isLocationOnSegment(
      LatLng point, LatLng p1, LatLng p2, double tolerance) {
    return Geolocator.distanceBetween(
                point.latitude, point.longitude, p1.latitude, p1.longitude) <=
            tolerance ||
        Geolocator.distanceBetween(
                point.latitude, point.longitude, p2.latitude, p2.longitude) <=
            tolerance;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
        northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }
}
