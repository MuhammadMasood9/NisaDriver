import 'package:driver/constant/constant.dart';
import 'package:driver/model/driver_rules_model.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/service_model.dart';
import 'package:driver/model/vehicle_type_model.dart';
import 'package:driver/model/zone_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class VehicleInformationController extends GetxController {
  Rx<TextEditingController> vehicleNumberController =
      TextEditingController().obs;
  Rx<TextEditingController> seatsController = TextEditingController().obs;
  Rx<TextEditingController> registrationDateController =
      TextEditingController().obs;
  Rx<TextEditingController> zoneNameController = TextEditingController().obs;
  Rx<DateTime?> selectedDate = DateTime.now().obs;

  RxBool isLoading = true.obs;

  Rx<String> selectedColor = "".obs;
  List<String> carColorList = <String>[
    'Red',
    'Black',
    'White',
    'Blue',
    'Green',
    'Orange',
    'Silver',
    'Gray',
    'Yellow',
    'Brown',
    'Gold',
    'Beige',
    'Purple'
  ].obs;
  List<String> sheetList = <String>[
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
    '13',
    '14',
    '15'
  ].obs;

  List<VehicleTypeModel> vehicleList = <VehicleTypeModel>[].obs;
  Rx<VehicleTypeModel> selectedVehicle = VehicleTypeModel().obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;
  RxList<ServiceModel> serviceList = <ServiceModel>[].obs;
  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  RxList selectedZone = <String>[].obs;
  Rx<String?> selectedServiceId = "".obs;
  RxString zoneString = "".obs;

  @override
  void onInit() {
    getVehicleType();
    super.onInit();
  }

  getVehicleType() async {
    isLoading.value = true;

    // Fetch services
    await FireStoreUtils.getService().then((value) {
      serviceList.value = value;
    });

    // Fetch zones
    await FireStoreUtils.getZone().then((value) {
      if (value != null) {
        zoneList.value = value;
      }
    });

    // Fetch driver profile
    String? currentUid = FireStoreUtils.getCurrentUid();
    if (currentUid != null) {
      await FireStoreUtils.getDriverProfile(currentUid).then((value) {
        driverModel.value = value!;
        if (driverModel.value.vehicleInformation != null) {
          vehicleNumberController.value.text =
              driverModel.value.vehicleInformation!.vehicleNumber.toString();
          selectedDate.value =
              driverModel.value.vehicleInformation!.registrationDate!.toDate();
          registrationDateController.value.text =
              DateFormat("dd-MM-yyyy").format(selectedDate.value!);
          selectedColor.value =
              driverModel.value.vehicleInformation!.vehicleColor.toString();
          seatsController.value.text =
              driverModel.value.vehicleInformation!.seats ?? "2";
        }

        if (driverModel.value.zoneIds != null) {
          for (var element in driverModel.value.zoneIds!) {
            List<ZoneModel> list =
                zoneList.where((p0) => p0.id == element).toList();
            if (list.isNotEmpty) {
              selectedZone.add(element);
              zoneString.value =
                  "$zoneString${zoneString.isEmpty ? "" : ","} ${Constant.localizationName(list.first.name)}";
            }
          }
          zoneNameController.value.text = zoneString.value;
        }

        if (driverModel.value.serviceId != null) {
          selectedServiceId.value = driverModel.value.serviceId;
        }
      });
    }

    // Fetch vehicle types
    await FireStoreUtils.getVehicleType().then((value) {
      vehicleList = value!;
      if (driverModel.value.vehicleInformation != null) {
        for (var element in vehicleList) {
          if (element.id ==
              driverModel.value.vehicleInformation!.vehicleTypeId) {
            selectedVehicle.value = element;
          }
        }
      }
    });

    isLoading.value = false;
    update();
  }
}
