import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/home_screens/order_map_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

// ~~~ MODEL DEFINITIONS (Provided for context) ~~~
import 'package:driver/model/language_name.dart';

class ZoneModel {
  List<GeoPoint>? area;
  bool? publish;
  double? latitude;
  List<LanguageName>? name;
  String? id;
  double? longitude;

  ZoneModel(
      {this.area,
      this.publish,
      this.latitude,
      this.name,
      this.id,
      this.longitude});

  ZoneModel.fromJson(Map<String, dynamic> json) {
    if (json['area'] != null) {
      area = <GeoPoint>[];
      json['area'].forEach((v) {
        area!.add(v);
      });
    }

    if (json['name'] != null) {
      name = <LanguageName>[];
      json['name'].forEach((v) {
        name!.add(LanguageName.fromJson(v));
      });
    }

    publish = json['publish'];
    latitude = json['latitude'];
    id = json['id'];
    longitude = json['longitude'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (area != null) {
      data['area'] = area!.map((v) => v).toList();
    }
    if (name != null) {
      data['name'] = name!.map((v) => v.toJson()).toList();
    }
    data['publish'] = publish;
    data['latitude'] = latitude;
    data['id'] = id;
    data['longitude'] = longitude;
    return data;
  }
}
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~ ENHANCED: ROUTE MATCHING RIDE FINDER ~~~~~~~~~~~~~~~~
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class RouteMatchingScreen extends StatefulWidget {
  const RouteMatchingScreen({super.key});

  @override
  State<RouteMatchingScreen> createState() => _RouteMatchingScreenState();
}

enum RouteSetupState { none, originSet, destinationSet, searching, rideFound }

class _RouteMatchingScreenState extends State<RouteMatchingScreen> {
  final HomeController controller = Get.find<HomeController>();
  GoogleMapController? _mapController;

  RouteSetupState _currentState = RouteSetupState.none;
  bool _isFetchingRoute = false;

  LatLng? _driverOrigin;
  LatLng? _driverDestination;
  String _driverOriginAddress = '';
  String _driverDestinationAddress = '';
  List<LatLng> _driverRoutePoints = [];

  OrderModel? _matchedRide;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  final Set<Polygon> _polygons = {};

  final List<List<LatLng>> _driverZonePolygons = [];

  Stream<List<OrderModel>>? _allNewOrdersBroadcastStream;
  StreamSubscription? _rideSearchSubscription;
  final Set<String> _shownRidePopups = {};

  final PolylinePoints _polylinePoints = PolylinePoints();

  // ----------------- IMPORTANT -----------------
  // 1. Replace "YOUR_GOOGLE_MAPS_API_KEY_HERE" with your actual Google Maps API key.
  // 2. Go to your Google Cloud Console and make sure the "Directions API" and "Places API" are enabled for your project.
  final String _googleApiKey =
      "AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4"; // YOUR_GOOGLE_MAPS_API_KEY_HERE
  // ---------------------------------------------

  final double _matchingToleranceMeters = 1000.0;

  BitmapDescriptor _originIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor _destinationIcon = BitmapDescriptor.defaultMarker;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    _fetchAndDrawDriverZones();

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

  Future<void> _showLocationSearchSheet({required bool isOrigin}) async {
    final result = await Get.bottomSheet(
      LocationSearchBottomSheet(
        isOrigin: isOrigin,
        apiKey: _googleApiKey,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

    if (result != null && result is LatLng) {
      if (isOrigin) {
        _setOrigin(result);
      } else {
        _setDestination(result);
      }
    }
  }

  Future<void> _setOrigin(LatLng position) async {
    if (!_isWithinServiceArea(position)) {
      Get.snackbar(
        'Out of Service Area'.tr,
        'The selected start point is outside your assigned zones.'.tr,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }
    _resetRoute();
    setState(() {
      _driverOrigin = position;
      _driverOriginAddress = 'Loading address...'.tr;
      _markers.add(Marker(
        markerId: const MarkerId('driver_origin'),
        position: _driverOrigin!,
        icon: _originIcon,
        infoWindow: InfoWindow(title: 'My Start'.tr),
      ));
    });
    // Do not change state here, wait for address
    _updateMarkerAddress(position, isOrigin: true);
  }

  Future<void> _setDestination(LatLng position) async {
    if (_driverOrigin == null) {
      Get.snackbar(
        'Set Start First'.tr,
        'Please set your starting point before the destination.'.tr,
      );
      return;
    }
    if (!_isWithinServiceArea(position)) {
      Get.snackbar(
        'Out of Service Area'.tr,
        'The selected destination is outside your assigned zones.'.tr,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    setState(() {
      _driverDestination = position;
      _driverDestinationAddress = 'Loading address...'.tr;
      _markers.removeWhere((m) => m.markerId.value == 'driver_destination');
      _markers.add(Marker(
        markerId: const MarkerId('driver_destination'),
        position: _driverDestination!,
        icon: _destinationIcon,
        infoWindow: InfoWindow(title: 'My Destination'.tr),
      ));
    });

    _updateMarkerAddress(position, isOrigin: false);
    await _drawDriverRoute();
    if (mounted && _driverRoutePoints.isNotEmpty) {
      setState(() => _currentState = RouteSetupState.destinationSet);
    }
  }

  void _clearPoint({required bool isOrigin}) {
    setState(() {
      if (isOrigin) {
        _resetRoute();
      } else {
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
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final placemark = placemarks.first;
        final address =
            '${placemark.name}, ${placemark.street}, ${placemark.locality}';
        setState(() {
          if (isOrigin) {
            _driverOriginAddress = address;
            _currentState = RouteSetupState.originSet;
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

        final userPickup = LatLng(order.sourceLocationLAtLng!.latitude!,
            order.sourceLocationLAtLng!.longitude!);
        if (!_isWithinServiceArea(userPickup)) {
          debugPrint(
              "Ride ${order.id} Ignored: Passenger pickup is outside the driver's assigned zones.");
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
      _polylines.removeWhere((p) => p.polylineId.value != "zone_polygon");
    });
  }

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
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ));
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

  Future<void> _fetchAndDrawDriverZones() async {
    final driverZoneIds = controller.driverModel.value.zoneIds ?? [];
    if (driverZoneIds.isEmpty) {
      debugPrint("Driver has no assigned zones.");
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection(CollectionName.zone)
          .where('id', whereIn: driverZoneIds)
          .where('publish', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint("No published zones found for the driver's assigned IDs.");
        return;
      }

      List<LatLng> allPoints = [];

      for (var doc in querySnapshot.docs) {
        final zone = ZoneModel.fromJson(doc.data());
        final List<GeoPoint> areaGeoPoints = zone.area ?? [];

        if (areaGeoPoints.isNotEmpty) {
          final polygonPoints = areaGeoPoints
              .map((gp) => LatLng(gp.latitude, gp.longitude))
              .toList();

          allPoints.addAll(polygonPoints);
          _driverZonePolygons.add(polygonPoints);

          _polygons.add(Polygon(
            polygonId: PolygonId(zone.id!),
            points: polygonPoints,
            strokeWidth: 2,
            strokeColor: AppColors.primary.withOpacity(0.8),
            fillColor: AppColors.primary.withOpacity(0.1),
          ));
        }
      }

      if (mounted) {
        setState(() {});
        if (allPoints.isNotEmpty) {
          final bounds = _boundsFromLatLngList(allPoints);
          _mapController
              ?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
        }
      }
    } catch (e) {
      debugPrint("Error fetching driver zones: $e");
      Get.snackbar(
        'Error'.tr,
        'Could not load service areas. Please try again later.'.tr,
        backgroundColor: Colors.red.shade600,
      );
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

    List<LatLng> allPoints = [..._driverRoutePoints, ...userRoutePoints];
    if (allPoints.isNotEmpty) {
      _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(_boundsFromLatLngList(allPoints), 80.0));
    }

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
      _startSearchingForRides();
    });
  }

  Future<List<LatLng>> _getRouteCoordinates(
      LatLng origin, LatLng destination) async {
    List<LatLng> polylineCoordinates = [];
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
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
      } else {
        debugPrint(
            "Directions API returned no points. Error: ${result.errorMessage}");
        Get.snackbar('Routing Error',
            'Could not find a route. Error: ${result.errorMessage}',
            backgroundColor: Colors.red.shade600, colorText: Colors.white);
      }
    } catch (e) {
      debugPrint("Error fetching polyline from Directions API: $e");
    }

    if (polylineCoordinates.isEmpty) {
      return [origin, destination];
    }
    return polylineCoordinates;
  }

  bool _isLocationOnPath(
      LatLng point, List<LatLng> polyline, double tolerance) {
    if (polyline.isEmpty) return false;

    for (final polylinePoint in polyline) {
      final double distance = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        polylinePoint.latitude,
        polylinePoint.longitude,
      );
      if (distance <= tolerance) {
        return true;
      }
    }
    return false;
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    double x = point.longitude;
    double y = point.latitude;
    bool isInside = false;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      double xi = polygon[i].longitude, yi = polygon[i].latitude;
      double xj = polygon[j].longitude, yj = polygon[j].latitude;
      bool intersect =
          ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) isInside = !isInside;
    }
    return isInside;
  }

  bool _isWithinServiceArea(LatLng point) {
    if (_driverZonePolygons.isEmpty) {
      // If no zones are defined, allow rides from anywhere.
      // Or return false to restrict to zones only. This behavior is up to business logic.
      return true;
    }
    for (final polygon in _driverZonePolygons) {
      if (_isPointInPolygon(point, polygon)) {
        return true;
      }
    }
    return false;
  }

  // ----------- WIDGET BUILDERS -----------

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(Constant.currentLocation?.latitude ?? 37.7749,
            Constant.currentLocation?.longitude ?? -122.4194),
        zoom: 12,
      ),
      onMapCreated: (mapController) async {
        _mapController = mapController;
        String style = await rootBundle.loadString('assets/map_style.json');
        _mapController?.setMapStyle(style);
        _fetchAndDrawDriverZones();
      },
      onTap: _handleMapTap,
      markers: _markers,
      polylines: _polylines,
      circles: _circles,
      polygons: _polygons,
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
      case RouteSetupState.originSet:
        instruction = _driverOrigin == null
            ? "Set your route to find rides".tr
            : "Now set your destination".tr;
        bgColor = AppColors.primary;
        icon = Icons.directions;
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
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
            elevation: 0,
            backgroundColor: Colors.white,
            child: const Icon(Icons.arrow_back, color: AppColors.primary),
          ),
          FloatingActionButton.small(
            heroTag: 'location_btn',
            elevation: 0,
            onPressed: () {
              if (Constant.currentLocation != null) {
                _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                  LatLng(Constant.currentLocation!.latitude!,
                      Constant.currentLocation!.longitude!),
                  15,
                ));
              }
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.my_location, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    Widget panelContent;

    switch (_currentState) {
      case RouteSetupState.none:
      case RouteSetupState.originSet:
        panelContent = _buildRouteSetupPanel();
        break;
      case RouteSetupState.destinationSet:
      case RouteSetupState.searching:
        panelContent = _buildRouteConfirmationPanel();
        break;
      case RouteSetupState.rideFound:
        panelContent = _buildMatchedRidePopup(_matchedRide!);
        break;
      default:
        panelContent = const SizedBox.shrink();
    }
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: panelContent,
      ),
    );
  }

  Widget _buildRouteSetupPanel() {
    return Container(
      key: const ValueKey('setupPanel'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      decoration: _panelBoxDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationDisplayRow(
            isOrigin: true,
            icon: Icons.trip_origin,
            iconColor: Colors.green.shade600,
            address: _driverOriginAddress,
            hint: 'Set start point'.tr,
            onTap: () => _showLocationSearchSheet(isOrigin: true),
            onClear: _driverOrigin != null
                ? () => _clearPoint(isOrigin: true)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12.0, top: 4, bottom: 4),
            child: Container(width: 2, height: 15, color: Colors.grey.shade300),
          ),
          _buildLocationDisplayRow(
            isOrigin: false,
            icon: Icons.flag,
            iconColor: Colors.red.shade600,
            address: _driverDestinationAddress,
            hint: 'Set destination'.tr,
            onTap: () => _showLocationSearchSheet(isOrigin: false),
            onClear: _driverDestination != null
                ? () => _clearPoint(isOrigin: false)
                : null,
            isLoading: _isFetchingRoute,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Finds rides within 1km of your route".tr,
                  style: AppTypography.appTitle(context)
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDisplayRow({
    required bool isOrigin,
    required IconData icon,
    required Color iconColor,
    required String address,
    required String hint,
    required VoidCallback onTap,
    VoidCallback? onClear,
    bool isLoading = false,
  }) {
    bool isSet = address.isNotEmpty;
    bool isActive = isOrigin || _driverOrigin != null;

    return Material(
      color: isActive ? AppColors.grey75 : AppColors.grey200,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: isActive ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? iconColor : Colors.grey.shade400,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isSet)
                      Text(
                        isOrigin ? 'Start'.tr : 'Destination'.tr,
                        style: AppTypography.input(context),
                      ),
                    Text(
                      isSet ? address : hint,
                      style: AppTypography.appTitle(context).copyWith(
                        color: isSet
                            ? Colors.black87
                            : (isActive
                                ? AppColors.primary
                                : Colors.grey.shade500),
                        fontWeight: isSet ? FontWeight.normal : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isLoading)
                const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                SizedBox(
                  width: 32,
                  height: 32,
                  child: onClear != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: onClear,
                          color: Colors.grey.shade500,
                        )
                      : Container(),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteConfirmationPanel() {
    bool isSearching = _currentState == RouteSetupState.searching;
    return Container(
      key: const ValueKey('confirmationPanel'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: _panelBoxDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: isSearching ? null : _resetRoute,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: Icon(Icons.refresh,
                      color: Colors.grey.shade700, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    icon: Icon(isSearching ? Icons.stop_circle : Icons.search),
                    label: Text(
                      isSearching ? "Stop Searching".tr : "Find Rides".tr,
                      style: AppTypography.buttonlight(context),
                    ),
                    onPressed:
                        isSearching ? _stopSearching : _startSearchingForRides,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isSearching ? Colors.red.shade600 : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedRidePopup(OrderModel order) => Container(
        key: const ValueKey('matchedRidePanel'),
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

  BoxDecoration _panelBoxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2)
      ],
    );
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
    final ByteData? byteData =
        await fi.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
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

// ~~~~~~~~~~~~~~~~~~~~~~ NEW WIDGET ~~~~~~~~~~~~~~~~~~~~~~
// This is a simple model for holding place prediction data from the Google API.
class PlacePrediction {
  final String description;
  final String placeId;

  PlacePrediction({required this.description, required this.placeId});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json['description'] as String,
      placeId: json['place_id'] as String,
    );
  }
}

// ~~~~~~~~~~ ENHANCED LocationSearchBottomSheet ~~~~~~~~~~
// This widget now uses the Google Places API for accurate address search.
class LocationSearchBottomSheet extends StatefulWidget {
  final bool isOrigin;
  final String apiKey;
  const LocationSearchBottomSheet(
      {super.key, required this.isOrigin, required this.apiKey});

  @override
  State<LocationSearchBottomSheet> createState() =>
      _LocationSearchBottomSheetState();
}

class _LocationSearchBottomSheetState extends State<LocationSearchBottomSheet> {
  final _textController = TextEditingController();
  List<PlacePrediction> _placePredictions = [];
  bool _isLoading = false;
  bool _isFetchingDetails = false;
  Timer? _debounce;
  String? _sessionToken;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    // Generate a new session token when the sheet is opened
    _sessionToken = _uuid.v4();
    _textController.addListener(() {
      _onInputChanged(_textController.text);
    });
  }

  // Debounce the search input to avoid excessive API calls
  void _onInputChanged(String input) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (input.length > 2) {
        _performSearch(input);
      } else {
        if (mounted) {
          setState(() {
            _placePredictions = [];
          });
        }
      }
    });
  }

  Future<void> _performSearch(String input) async {
    if (!mounted || _sessionToken == null) return;
    setState(() => _isLoading = true);

    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=${widget.apiKey}&sessiontoken=$_sessionToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['predictions'] != null && mounted) {
          setState(() {
            _placePredictions = (body['predictions'] as List)
                .map((p) => PlacePrediction.fromJson(p))
                .toList();
          });
        }
      } else {
        debugPrint("Places API Error: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error fetching places: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getPlaceDetailsAndPop(String placeId) async {
    if (!mounted || _sessionToken == null) return;
    FocusScope.of(context).unfocus(); // Hide keyboard
    setState(() => _isFetchingDetails = true);

    String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=${widget.apiKey}&sessiontoken=$_sessionToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['result'] != null && body['result']['geometry'] != null) {
          final location = body['result']['geometry']['location'];
          final latLng = LatLng(location['lat'], location['lng']);
          if (mounted) {
            Get.back(result: latLng);
          }
        }
      } else {
        debugPrint("Place Details API Error: ${response.body}");
        Get.snackbar(
          'Error'.tr,
          'Could not retrieve location details. Please try again.'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint("Error fetching place details: $e");
    } finally {
      if (mounted) {
        // A session token is used for one search 'session' which includes
        // the autocomplete requests and one details request. Invalidate it after use.
        setState(() {
          _sessionToken = null;
          _isFetchingDetails = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isOrigin
                        ? "Set Your Start Point".tr
                        : "Set Your Destination".tr,
                    style: AppTypography.boldLabel(context)
                        .copyWith(color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    autofocus: true,
                    onSubmitted: (_) => _performSearch(_textController.text),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: "Enter an address or place name...".tr,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Stack(
                children: [
                  _buildResultsList(),
                  if (_isFetchingDetails)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withOpacity(0.7),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_textController.text.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Start typing an address to see results.'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ),
      );
    }

    if (_placePredictions.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No results found.'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _placePredictions.length,
      itemBuilder: (context, index) {
        final prediction = _placePredictions[index];
        return ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: Text(prediction.description),
          onTap: () => _getPlaceDetailsAndPop(prediction.placeId),
        );
      },
    );
  }
}
