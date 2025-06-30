// lib/model/scheduled_ride_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/model/contact_model.dart';
import 'package:driver/model/order/location_lat_lng.dart';
import 'package:driver/model/service_model.dart';
import 'package:driver/model/zone_model.dart';

class RideHistoryEntry {
  Timestamp? rideDate;
  String? orderId;
  String? status;
  String? finalRate;

  RideHistoryEntry({
    this.rideDate,
    this.orderId,
    this.status,
    this.finalRate,
  });

  RideHistoryEntry.fromJson(Map<String, dynamic> json) {
    rideDate = json['rideDate'];
    orderId = json['orderId'];
    status = json['status'];
    finalRate = json['finalRate'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['rideDate'] = rideDate;
    data['orderId'] = orderId;
    data['status'] = status;
    data['finalRate'] = finalRate;
    return data;
  }
}

class ScheduleRideModel {
  String? id;
  String? userId;
  String? driverId;

  // Ride Details
  String? sourceLocationName;
  String? destinationLocationName;
  LocationLatLng? sourceLocationLAtLng;
  LocationLatLng? destinationLocationLAtLng;
  String? distance;
  String? distanceType;
  ServiceModel? service;
  String? serviceId;
  ContactModel? someOneElse;

  // Schedule & Timing
  String? scheduledTime;
  List<String>? recursOnDays;
  Timestamp? startDate;
  Timestamp? endDate;

  // Billing & Payment
  String? singleRideRate;
  String? weeklyRate;
  String? paymentType;
  String? paymentStatus; // 'unpaid', 'paid'

  // MODIFIED: Enhanced status and tracking
  String? status; // 'pending', 'accepted', 'active', 'completed', 'cancelled'
  String? currentWeekOtp; // NEW: OTP for the first ride to activate the schedule
  List<String>? acceptedDriverId;
  List<String>? rejectedDriverId;
  List<Timestamp>? missedRideDates;
  Timestamp? createdAt;

  // NEW: Field to track the history of daily rides.
  List<RideHistoryEntry>? rideHistory;

  // Other details
  String? orderType;
  String? zoneId;
  ZoneModel? zone;
  String? finalRate; // Kept for compatibility

  ScheduleRideModel({
    this.id,
    this.userId,
    this.driverId,
    this.sourceLocationName,
    this.destinationLocationName,
    this.sourceLocationLAtLng,
    this.destinationLocationLAtLng,
    this.distance,
    this.distanceType,
    this.serviceId,
    this.service,
    this.scheduledTime,
    this.recursOnDays,
    this.startDate,
    this.endDate,
    this.singleRideRate,
    this.weeklyRate,
    this.paymentType,
    this.paymentStatus,
    this.status,
    this.currentWeekOtp,
    this.acceptedDriverId,
    this.rejectedDriverId,
    this.missedRideDates,
    this.createdAt,
    this.orderType,
    this.zoneId,
    this.zone,
    this.someOneElse,
    this.finalRate,
    this.rideHistory, // NEW
  });

  ScheduleRideModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    userId = json['userId'];
    driverId = json['driverId'];
    sourceLocationName = json['sourceLocationName'];
    destinationLocationName = json['destinationLocationName'];
    sourceLocationLAtLng = json['sourceLocationLAtLng'] != null ? LocationLatLng.fromJson(json['sourceLocationLAtLng']) : null;
    destinationLocationLAtLng = json['destinationLocationLAtLng'] != null ? LocationLatLng.fromJson(json['destinationLocationLAtLng']) : null;
    distance = json['distance'];
    distanceType = json['distanceType'];
    finalRate = json['finalRate'];
    serviceId = json['serviceId'];
    service = json['service'] != null ? ServiceModel.fromJson(json['service']) : null;
    scheduledTime = json['scheduledTime'];
    recursOnDays = json['recursOnDays'] != null ? List<String>.from(json['recursOnDays']) : null;
    startDate = json['startDate'];
    endDate = json['endDate'];
    singleRideRate = json['singleRideRate'];
    weeklyRate = json['weeklyRate'];
    paymentType = json['paymentType'];
    paymentStatus = json['paymentStatus'];
    status = json['status'];
    currentWeekOtp = json['currentWeekOtp'];
    acceptedDriverId = json['acceptedDriverId'] != null ? List<String>.from(json['acceptedDriverId']) : [];
    rejectedDriverId = json['rejectedDriverId'] != null ? List<String>.from(json['rejectedDriverId']) : [];
    if (json['missedRideDates'] != null) {
      missedRideDates = (json['missedRideDates'] as List<dynamic>).map((e) => e as Timestamp).toList();
    }
    // NEW: Deserialize ride history.
    if (json['rideHistory'] != null) {
      rideHistory = <RideHistoryEntry>[];
      json['rideHistory'].forEach((v) {
        rideHistory!.add(RideHistoryEntry.fromJson(v));
      });
    } else {
      rideHistory = [];
    }
    createdAt = json['createdAt'];
    orderType = json['orderType'];
    zoneId = json['zoneId'];
    zone = json['zone'] != null ? ZoneModel.fromJson(json['zone']) : null;
    someOneElse = json['someOneElse'] != null ? ContactModel.fromJson(json['someOneElse']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['userId'] = userId;
    data['driverId'] = driverId;
    data['sourceLocationName'] = sourceLocationName;
    data['destinationLocationName'] = destinationLocationName;
    if (sourceLocationLAtLng != null) {
      data['sourceLocationLAtLng'] = sourceLocationLAtLng!.toJson();
    }
    if (destinationLocationLAtLng != null) {
      data['destinationLocationLAtLng'] = destinationLocationLAtLng!.toJson();
    }
    data['distance'] = distance;
    data['distanceType'] = distanceType;
    data['serviceId'] = serviceId;
    if (service != null) {
      data['service'] = service!.toJson();
    }
    data['scheduledTime'] = scheduledTime;
    data['recursOnDays'] = recursOnDays;
    data['startDate'] = startDate;
    data['endDate'] = endDate;
    data['singleRideRate'] = singleRideRate;
    data['weeklyRate'] = weeklyRate;
    data['paymentType'] = paymentType;
    data['paymentStatus'] = paymentStatus;
    data['status'] = status;
    data['currentWeekOtp'] = currentWeekOtp;
    data['acceptedDriverId'] = acceptedDriverId;
    data['rejectedDriverId'] = rejectedDriverId;
    data['missedRideDates'] = missedRideDates;
    // NEW: Serialize ride history.
    if (rideHistory != null) {
      data['rideHistory'] = rideHistory!.map((v) => v.toJson()).toList();
    }
    data['createdAt'] = createdAt;
    data['orderType'] = orderType;
    data['zoneId'] = zoneId;
    data['finalRate'] = finalRate;
    if (zone != null) {
      data['zone'] = zone!.toJson();
    }
    if (someOneElse != null) {
      data['someOneElse'] = someOneElse!.toJson();
    }
    return data;
  }
}