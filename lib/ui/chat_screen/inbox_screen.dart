import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/inbox_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:driver/widget/firebase_pagination/src/models/view_type.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<InboxModel> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteChat(String orderId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection(CollectionName.chat)
          .where('orderId', isEqualTo: orderId)
          .where('driverId', isEqualTo: FireStoreUtils.getCurrentUid())
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      setState(() {
        _searchResults.removeWhere((item) => item.orderId == orderId);
        _isLoading = false;
      });

      Get.snackbar(
        'Success',
        'Chat deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Error',
        'Failed to delete chat',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  Future<void> _fetchSearchResults() async {
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection(CollectionName.chat)
          .where("driverId", isEqualTo: FireStoreUtils.getCurrentUid())
          .orderBy('createdAt', descending: true)
          .get();

      final results = querySnapshot.docs
          .map((doc) => InboxModel.fromJson(doc.data() as Map<String, dynamic>))
          .where((inbox) =>
              inbox.customerName!
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              inbox.orderId!.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildChatItem(InboxModel inboxModel, BuildContext context) {
    return InkWell(
      onTap: () async {
        UserModel? customer =
            await FireStoreUtils.getCustomer(inboxModel.customerId.toString());
        DriverUserModel? driver = await FireStoreUtils.getDriverProfile(
            inboxModel.driverId.toString());

        Get.to(ChatScreens(
          driverId: driver!.id,
          customerId: customer!.id,
          customerName: customer.fullName,
          customerProfileImage: customer.profilePic,
          driverName: driver.fullName,
          driverProfileImage: driver.profilePic,
          orderId: inboxModel.orderId,
          token: customer.fcmToken,
        ));
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.background,
            title:
                Text("Delete Chat", style: AppTypography.boldHeaders(context)),
            content: Text("Are you sure you want to delete this chat?",
                style: AppTypography.caption(context)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel",
                    style:
                        GoogleFonts.poppins(color: AppColors.darkBackground)),
              ),
              TextButton(
                onPressed: () {
                  _deleteChat(inboxModel.orderId!);
                  Navigator.pop(context);
                },
                child: Text("Delete",
                    style: GoogleFonts.poppins(color: AppColors.primary)),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(6)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 0),
            child: ListTile(
              leading: ClipOval(
                child: CachedNetworkImage(
                  width: 40,
                  height: 40,
                  imageUrl: inboxModel.driverProfileImage.toString(),
                  imageBuilder: (context, imageProvider) => Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.network(
                      Constant.userPlaceHolder,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      inboxModel.customerName.toString(),
                      style: AppTypography.boldLabel(context),
                    ),
                  ),
                  Text(
                    Constant.dateFormatTimestamp(inboxModel.createdAt),
                    style: AppTypography.label(context),
                  ),
                ],
              ),
              subtitle: Text(
                "Last Message: ${inboxModel.lastMessage}".tr,
                style: AppTypography.label(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(height: Responsive.width(3, context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.containerBorder, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search conversations...".tr,
                  hintStyle: AppTypography.caption(context)
                      .copyWith(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                            _fetchSearchResults();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                onChanged: _performSearch,
                onSubmitted: (_) => _fetchSearchResults(),
              ),
            ),
          ),
          SizedBox(height: Responsive.width(3, context)),
          Expanded(
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.only(top: 0, left: 10, right: 10),
                child: _searchQuery.isNotEmpty
                    ? _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 24.0,
                              height: 24.0,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                              ),
                            ),
                          )
                        : _searchResults.isEmpty
                            ? Center(
                                child: Text("No results found".tr,
                                    style: GoogleFonts.poppins()))
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  return _buildChatItem(
                                      _searchResults[index], context);
                                },
                              )
                    : FirestorePagination(
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, documentSnapshots, index) {
                          final data = documentSnapshots[index].data()
                              as Map<String, dynamic>?;
                          InboxModel inboxModel = InboxModel.fromJson(data!);
                          return _buildChatItem(inboxModel, context);
                        },
                        shrinkWrap: true,
                        onEmpty: Center(
                            child: Text("No Conversion found".tr,
                                style: GoogleFonts.poppins())),
                        query: FirebaseFirestore.instance
                            .collection(CollectionName.chat)
                            .where("driverId",
                                isEqualTo: FireStoreUtils.getCurrentUid())
                            .orderBy('createdAt', descending: true),
                        viewType: ViewType.list,
                        initialLoader: const Center(
                          child: SizedBox(
                            width: 24.0,
                            height: 24.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                            ),
                          ),
                        ),
                        isLive: true,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
