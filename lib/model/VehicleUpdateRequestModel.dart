import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/model/language_name.dart';

class VehicleInformationRequest {
  List<LanguageName>? vehicleType;
  String? vehicleTypeId;
  Timestamp? registrationDate;
  String? vehicleColor;
  String? vehicleNumber;
  String? seats;
  String? driverId; // New field
  String? driverName; // New field
  String? status; // New field (default: "pending")

  VehicleInformationRequest({
    this.vehicleType,
    this.vehicleTypeId,
    this.registrationDate,
    this.vehicleColor,
    this.vehicleNumber,
    this.seats,
    this.driverId,
    this.driverName,
    this.status,
  });

  VehicleInformationRequest.fromJson(Map<String, dynamic> json) {
    if (json['vehicleType'] != null) {
      vehicleType = <LanguageName>[];
      json['vehicleType'].forEach((v) {
        vehicleType!.add(LanguageName.fromJson(v));
      });
    }
    vehicleTypeId = json['vehicleTypeId'];
    registrationDate = json['registrationDate'];
    vehicleColor = json['vehicleColor'];
    vehicleNumber = json['vehicleNumber'];
    seats = json['seats'];
    driverId = json['driverId'];
    driverName = json['driverName'];
    status = json['status'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (vehicleType != null) {
      data['vehicleType'] = vehicleType!.map((v) => v.toJson()).toList();
    }
    data['vehicleTypeId'] = vehicleTypeId;
    data['registrationDate'] = registrationDate;
    data['vehicleColor'] = vehicleColor;
    data['vehicleNumber'] = vehicleNumber;
    data['seats'] = seats;
    data['driverId'] = driverId;
    data['driverName'] = driverName;
    data['status'] = status;
    return data;
  }
}