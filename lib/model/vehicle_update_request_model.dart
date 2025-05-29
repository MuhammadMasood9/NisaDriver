import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/model/driver_user_model.dart';

class VehicleUpdateRequestModel {
  String? id;
  String? driverId;
  String? driverName;
  String? driverEmail;
  String? reason;
  String? status;
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
    id = json['id'];
    driverId = json['driverId'];
    driverName = json['driverName'];
    driverEmail = json['driverEmail'];
    reason = json['reason'];
    status = json['status'];
    requestDate = json['requestDate'];
    responseDate = json['responseDate'];
    adminId = json['adminId'];
    adminNotes = json['adminNotes'];
    rejectionReason = json['rejectionReason'];
    currentVehicleInfo = json['currentVehicleInfo'] != null
        ? VehicleInformation.fromJson(json['currentVehicleInfo'])
        : null;
    requestedVehicleInfo = json['requestedVehicleInfo'] != null
        ? VehicleInformation.fromJson(json['requestedVehicleInfo'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['driverId'] = driverId;
    data['driverName'] = driverName;
    data['driverEmail'] = driverEmail;
    data['reason'] = reason;
    data['status'] = status;
    data['requestDate'] = requestDate;
    data['responseDate'] = responseDate;
    data['adminId'] = adminId;
    data['adminNotes'] = adminNotes;
    data['rejectionReason'] = rejectionReason;
    if (currentVehicleInfo != null) {
      data['currentVehicleInfo'] = currentVehicleInfo!.toJson();
    }
    if (requestedVehicleInfo != null) {
      data['requestedVehicleInfo'] = requestedVehicleInfo!.toJson();
    }
    return data;
  }
}
