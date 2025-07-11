import 'dart:async';
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ~~~ MODEL DEFINITIONS (Provided for context) ~~~

import 'package:driver/model/language_name.dart';

class ZoneModel {
  List<GeoPoint>? area;
  bool? publish;
  double? latitude;
  List<LanguageName>? name;
  String? id;
  double? longitude;

  ZoneModel({this.area, this.publish, this.latitude, this.name, this.id, this.longitude});

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
  // 2. Go to your Google Cloud Console and make sure the "Directions API" is enabled for your project.
  final String _googleApiKey = "AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4";
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
    if (_currentState == RouteSetupState.searching || _currentState == RouteSetupState.rideFound) return;

    if (_currentState == RouteSetupState.none) {
      _setOrigin(position);
    } else if (_currentState == RouteSetupState.originSet) {
      _setDestination(position);
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

  Future<void> _updateMarkerAddress(LatLng position, {required bool isOrigin}) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
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

  void _startSearchingForRides() {
    if (_driverRoutePoints.isEmpty || _allNewOrdersBroadcastStream == null) {
      Get.snackbar('Error'.tr, 'Cannot start search without a valid route.'.tr);
      return;
    }
    setState(() => _currentState = RouteSetupState.searching);
    _rideSearchSubscription = _allNewOrdersBroadcastStream!.listen((orders) {
      if (!mounted || _currentState != RouteSetupState.searching) return;

      final potentialRide = orders.firstWhereOrNull((order) {
        if (_shownRidePopups.contains(order.id) || order.sourceLocationLAtLng == null || order.destinationLocationLAtLng == null) {
          return false;
        }

        final userPickup = LatLng(order.sourceLocationLAtLng!.latitude!, order.sourceLocationLAtLng!.longitude!);
        if (!_isWithinServiceArea(userPickup)) {
          debugPrint("Ride ${order.id} Ignored: Passenger pickup is outside the driver's assigned zones.");
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
    final userPickup = LatLng(order.sourceLocationLAtLng!.latitude!, order.sourceLocationLAtLng!.longitude!);
    final userDropoff = LatLng(order.destinationLocationLAtLng!.latitude!, order.destinationLocationLAtLng!.longitude!);

    final isPickupOnPath = _isLocationOnPath(userPickup, _driverRoutePoints, _matchingToleranceMeters);
    final isDropoffOnPath = _isLocationOnPath(userDropoff, _driverRoutePoints, _matchingToleranceMeters);

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

  Future<void> _drawDriverRoute() async {
    if (_driverOrigin == null || _driverDestination == null) return;
    setState(() => _isFetchingRoute = true);

    _polylines.removeWhere((p) => p.polylineId.value == 'driver_route');
    _circles.clear();

    try {
      final points = await _getRouteCoordinates(_driverOrigin!, _driverDestination!);
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

          for (int i = 0; i < _driverRoutePoints.length; i++) {
            _circles.add(Circle(
              circleId: CircleId('tolerance_circle_$i'),
              center: _driverRoutePoints[i],
              radius: _matchingToleranceMeters,
              fillColor: AppColors.primary.withOpacity(0),
              strokeWidth: 1,
              strokeColor: AppColors.primary.withOpacity(0),
            ));
          }

          final bounds = _boundsFromLatLngList([_driverOrigin!, _driverDestination!]);
          _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
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
        
        if(areaGeoPoints.isNotEmpty) {
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

      if(mounted) {
        setState(() {});
        if(allPoints.isNotEmpty) {
           final bounds = _boundsFromLatLngList(allPoints);
          _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
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

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
            Constant.currentLocation?.latitude ?? 37.7749,
            Constant.currentLocation?.longitude ?? -122.4194),
        zoom: 12,
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
      polygons: _polygons,
      myLocationButtonEnabled: false,
      myLocationEnabled: true,
      zoomControlsEnabled: false,
    );
  }

  bool _isWithinServiceArea(LatLng point) {
    if (_driverZonePolygons.isEmpty) {
      debugPrint("Service area check failed: No driver zone polygons loaded.");
      return false;
    }
    
    for (final polygon in _driverZonePolygons) {
       if (_isPointInPolygon(point, polygon)) {
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

        bool intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
        if (intersect) {
          isInside = !isInside;
        }
    }
    return isInside;
  }
  
  Future<void> _showMatchedRideOnMap(OrderModel ride) async {
    final userPickup = LatLng(ride.sourceLocationLAtLng!.latitude!, ride.sourceLocationLAtLng!.longitude!);
    final userDropoff = LatLng(ride.destinationLocationLAtLng!.latitude!, ride.destinationLocationLAtLng!.longitude!);

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
    if(allPoints.isNotEmpty){
       _mapController?.animateCamera(CameraUpdate.newLatLngBounds(_boundsFromLatLngList(allPoints), 80.0));
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

  // ----------- FIXED & MOST IMPORTANT FUNCTION -----------
  // This function now correctly calls the Directions API to get a road-based route.
  Future<List<LatLng>> _getRouteCoordinates(LatLng origin, LatLng destination) async {
    // Prevent API calls if the key is a placeholder or empty. This is why you saw a straight line.
    

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
        // The API call was successful, and we have route points.
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
      } else {
        // The API call was made, but it returned no points (e.g., no route found).
        debugPrint("Directions API returned no points. Error: ${result.errorMessage}");
         Get.snackbar(
          'Routing Error',
          'Could not find a route between the selected points. Error: ${result.errorMessage}',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white
        );
      }
    } catch (e) {
      debugPrint("Error fetching polyline from Directions API: $e");
    }

    // If polyline fetch failed or returned no points, fallback to a straight line.
    if (polylineCoordinates.isEmpty) {
      return [origin, destination];
    }

    return polylineCoordinates;
  }
  
  bool _isLocationOnPath(LatLng point, List<LatLng> polyline, double tolerance) {
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

  // --- Widget Builders (Unchanged) ---
  
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
            onPressed: () {
              if (Constant.currentLocation != null) {
                _mapController?.animateCamera(CameraUpdate.newLatLng(
                  LatLng(Constant.currentLocation!.latitude!,
                      Constant.currentLocation!.longitude!),
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
      bottom: showPanel ? 0 : -350,
      left: 0,
      right: 0,
      child: panelContent,
    );
  }

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.radar, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Finds rides within a 1km of your route".tr,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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