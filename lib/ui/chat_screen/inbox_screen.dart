import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/inbox_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Handles the deletion of a chat conversation after user confirmation.
  Future<bool> _deleteChat(String orderId) async {
    try {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            'Delete Chat?'.tr,
            style: AppTypography.appTitle(context),
          ),
          content: Text(
            'This will permanently delete the conversation.'.tr,
            style: AppTypography.caption(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel'.tr,
                style: AppTypography.boldLabel(context)
                    .copyWith(color: AppColors.grey500),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete'.tr,
                style: AppTypography.boldLabel(context)
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );

      if (confirm != true) return false;

      // Use a batch write to delete all messages in the conversation for this driver
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection(CollectionName.chat)
          .where('orderId', isEqualTo: orderId)
          .where('driverId', isEqualTo: FireStoreUtils.getCurrentUid())
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      Get.snackbar(
        'Success'.tr,
        'Chat deleted successfully'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      Get.snackbar(
        'Error'.tr,
        'Failed to delete chat: $e'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _buildBody(context),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading conversations...'.tr,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: _buildSearchField(context),
        ),
        Expanded(
          child: FirestorePagination(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemBuilder: (context, documentSnapshots, index) {
              final data =
                  documentSnapshots[index].data() as Map<String, dynamic>?;
              if (data == null) return const SizedBox();

              InboxModel inboxModel = InboxModel.fromJson(data);

              // Client-side filtering for search functionality
              if (_searchQuery.isNotEmpty &&
                  !inboxModel.customerName!
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()) &&
                  !inboxModel.orderId!
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase())) {
                return const SizedBox.shrink();
              }
              return _buildChatItem(context, inboxModel);
            },
            onEmpty: _buildInfoState(
              context,
              icon: Icons.chat_bubble_outline,
              title: "No Conversations Yet".tr,
              subtitle: "Your chats with customers will appear here.".tr,
            ),
            query: FirebaseFirestore.instance
                .collection(CollectionName.chat)
                .where("driverId", isEqualTo: FireStoreUtils.getCurrentUid())
                .orderBy('createdAt', descending: true),
            isLive: true,
            initialLoader: _buildLoader(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: AppTypography.label(context),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, size: 20, color: AppColors.primary),
          hintText: "Search by customer or ride ID...".tr,
          hintStyle: AppTypography.label(context)
              .copyWith(color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildChatItem(BuildContext context, InboxModel inboxModel) {
    return Dismissible(
      key: Key(inboxModel.orderId.toString()),
      confirmDismiss: (direction) async {
        return await _deleteChat(inboxModel.orderId.toString());
      },
      direction: DismissDirection.endToStart,
      background: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 8),
            Text("Delete", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () async {
          UserModel? customer = await FireStoreUtils.getCustomer(
              inboxModel.customerId.toString());
          DriverUserModel? driver = await FireStoreUtils.getDriverProfile(
              inboxModel.driverId.toString());

          if (customer != null && driver != null) {
            Get.to(() => ChatScreens(
                  driverId: driver.id,
                  customerId: customer.id,
                  customerName: customer.fullName,
                  customerProfileImage: customer.profilePic,
                  driverName: driver.fullName,
                  driverProfileImage: driver.profilePic,
                  orderId: inboxModel.orderId,
                  token: customer.fcmToken,
                ));
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200, width: 1.0),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5)),
                child: ClipOval(
                  child: CachedNetworkImage(
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                    imageUrl: inboxModel.customerProfileImage.toString(),
                    placeholder: (context, url) => Constant.loader(context),
                    errorWidget: (context, url, error) => Image.network(
                        Constant.userPlaceHolder,
                        fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inboxModel.customerName.toString(),
                        style: AppTypography.boldLabel(context)),
                    const SizedBox(height: 4),
                    Text(
                      inboxModel.lastMessage.toString(),
                      style: AppTypography.label(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(Constant.dateFormatTimestamp(inboxModel.createdAt),
                      style: AppTypography.smBoldLabel(context)),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: AppTypography.headers(context)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.label(context)),
          ],
        ),
      ),
    );
  }
}
