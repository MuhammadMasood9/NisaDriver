import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:driver/model/vehicle_information.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/driver_rules_model.dart';
import 'package:driver/model/language_name.dart';

class VehicleUpdateRequestModel {
  String? id;
  String? driverId;
  String? driverName;
  String? driverEmail;
  String? reason;
  String? status; // pending, approved, rejected
  Timestamp? requestDate;
  Timestamp? responseDate;
  String? adminId;
  String? adminNotes;
  String? rejectionReason;
  VehicleInformation? currentVehicleInfo;
  VehicleInformation? requestedVehicleInfo;

  VehicleUpdateRequestModel({
    this.id,
    this.driverId,
    this.driverName,
    this.driverEmail,
    this.reason,
    this.status,
    this.requestDate,
    this.responseDate,
    this.adminId,
    this.adminNotes,
    this.rejectionReason,
    this.currentVehicleInfo,
    this.requestedVehicleInfo,
  });

  VehicleUpdateRequestModel.fromJson(Map<String, dynamic> json) {
    try {
      id = json['id'];
      driverId = json['driver_id'];
      driverName = json['driver_name'];
      driverEmail = json['driver_email'];
      reason = json['reason'];
      status = json['status'];
      requestDate = json['request_date'];
      responseDate = json['response_date'];
      adminId = json['admin_id'];
      adminNotes = json['admin_notes'];
      rejectionReason = json['rejection_reason'];

      if (json['current_vehicle_info'] != null) {
        currentVehicleInfo =
            VehicleInformation.fromJson(json['current_vehicle_info']);
      }

      if (json['requested_vehicle_info'] != null) {
        requestedVehicleInfo =
            VehicleInformation.fromJson(json['requested_vehicle_info']);
      }
    } catch (e) {
      print("Error parsing VehicleUpdateRequestModel: $e");
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['driver_id'] = driverId;
    data['driver_name'] = driverName;
    data['driver_email'] = driverEmail;
    data['reason'] = reason;
    data['status'] = status;
    data['request_date'] = requestDate;
    data['response_date'] = responseDate;
    data['admin_id'] = adminId;
    data['admin_notes'] = adminNotes;
    data['rejection_reason'] = rejectionReason;

    if (currentVehicleInfo != null) {
      data['current_vehicle_info'] = currentVehicleInfo!.toJson();
    }

    if (requestedVehicleInfo != null) {
      data['requested_vehicle_info'] = requestedVehicleInfo!.toJson();
    }

    return data;
  }
}
