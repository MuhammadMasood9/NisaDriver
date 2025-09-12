import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';

import 'package:driver/model/conversation_model.dart';
import 'package:driver/model/inbox_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/FullScreenImageViewer.dart';
import 'package:driver/ui/chat_screen/FullScreenVideoViewer.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:driver/widget/firebase_pagination/src/models/view_type.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class ChatScreens extends StatefulWidget {
  final String? orderId;
  final String? customerId;
  final String? customerName;
  final String? customerProfileImage;
  final String? driverId;
  final String? driverName;
  final String? driverProfileImage;
  final String? token;

  const ChatScreens({
    super.key,
    this.orderId,
    this.customerId,
    this.customerName,
    this.driverName,
    this.driverId,
    this.customerProfileImage,
    this.driverProfileImage,
    this.token,
  });

  @override
  State<ChatScreens> createState() => _ChatScreensState();
}

class _ChatScreensState extends State<ChatScreens> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _controller = ScrollController();

  // State variables
  ConversationModel? _replyingToMessage;
  final bool _isBannerVisible = true;
  final GlobalKey _attachmentButtonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    if (_controller.hasClients) {
      Timer(const Duration(milliseconds: 500),
          () => _controller.jumpTo(_controller.position.maxScrollExtent));
    }
    log("Customer Id: ${widget.customerId} , Driver Id: ${widget.driverId}");
  }

  // --- Attachment Menu Logic ---

  void _hideAttachmentMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleAttachmentMenu() {
    if (_overlayEntry != null) {
      _hideAttachmentMenu();
    } else {
      _showAttachmentMenu();
    }
  }

  void _showAttachmentMenu() {
    final overlay = Overlay.of(context);
    final renderBox =
        _attachmentButtonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    final List<Map<String, dynamic>> menuOptions = [
      {
        'icon': Icons.photo_library_rounded,
        'color': Colors.blue,
        'label': 'Photos & videos'.tr,
        'onTap': () async {
          XFile? image =
              await _imagePicker.pickImage(source: ImageSource.gallery);
          if (image != null) {
            Url url =
                await Constant().uploadChatImageToFireStorage(File(image.path));
            _sendMessage('', url, '', 'image');
          }
        },
      },
      {
        'icon': Icons.camera_alt_rounded,
        'color': Colors.pink,
        'label': 'Camera'.tr,
        'onTap': () async {
          XFile? image =
              await _imagePicker.pickImage(source: ImageSource.camera);
          if (image != null) {
            Url url =
                await Constant().uploadChatImageToFireStorage(File(image.path));
            _sendMessage('', url, '', 'image');
          }
        },
      },
    ];

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideAttachmentMenu,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height - offset.dy + 12,
            left: offset.dx + 2,
            child: Material(
              color: Colors.transparent,
              child: _buildFloatingMenu(menuOptions),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  Widget _buildFloatingMenu(List<Map<String, dynamic>> options) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      width: 200,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          return _buildMenuItem(
            icon: option['icon'],
            iconColor: option['color'],
            label: option['label'],
            onTap: () {
              _hideAttachmentMenu();
              option['onTap']();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.white.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 16),
              Text(label, style: AppTypography.boldLabel(context)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideAttachmentMenu();
    _messageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // --- Reply, Edit, Delete Logic ---

  void _startReply(ConversationModel message) {
    setState(() => _replyingToMessage = message);
  }

  void _cancelReply() {
    setState(() => _replyingToMessage = null);
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.orderId)
          .collection('thread')
          .doc(messageId)
          .delete();
      ShowToastDialog.showToast("Message deleted successfully".tr);
    } catch (e) {
      ShowToastDialog.showToast("Failed to delete message: $e".tr);
    }
  }

  Future<void> _editMessage(String messageId, String newMessage) async {
    try {
      await FirebaseFirestore.instance
          .collection('chat')
          .doc(widget.orderId)
          .collection('thread')
          .doc(messageId)
          .update({'message': newMessage});
      ShowToastDialog.showToast("Message updated successfully".tr);
    } catch (e) {
      ShowToastDialog.showToast("Failed to update message: $e".tr);
    }
  }

  // --- UI Build Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            if (_isBannerVisible) _buildSafetyBanner(),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: FirestorePagination(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, documentSnapshots, index) {
                    final documentSnapshot = documentSnapshots[index];
                    final data =
                        documentSnapshot.data() as Map<String, dynamic>;
                    final message = ConversationModel.fromJson(data);
                    final isMe =
                        message.senderId == FireStoreUtils.getCurrentUid();
                    return _buildMessageBubble(message, isMe);
                  },
                  query: FirebaseFirestore.instance
                      .collection('chat')
                      .doc(widget.orderId)
                      .collection("thread")
                      .orderBy('createdAt', descending: false),
                  isLive: true,
                  onEmpty: Center(child: Text("Start the conversation!".tr)),
                  viewType: ViewType.list,
                ),
              ),
            ),
            _buildSuggestedReplies(),
            if (_replyingToMessage != null) _buildReplyPreview(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      surfaceTintColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      backgroundColor: Colors.white,
      leading: IconButton(
        onPressed: () => Get.back(),
        icon: const Icon(Icons.arrow_back, color: Colors.black),
      ),
      title: Row(
        children: [
          ClipOval(
            child: CachedNetworkImage(
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              imageUrl: widget.customerProfileImage ?? Constant.userPlaceHolder,
              errorWidget: (context, url, error) => Image.asset(
                'assets/images/profile_placeholder.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.customerName ?? 'Customer Name'.tr,
                style: AppTypography.appTitle(context),
              ),
              Text(
                'Customer'.tr,
                style: AppTypography.smBoldLabel(Get.context!)
                    .copyWith(color: AppColors.grey500),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            ShowToastDialog.showToast("In-app call feature coming soon!".tr);
          },
          icon: const Icon(Icons.call, color: Colors.black, size: 26),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSafetyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.grey100, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'For your safety, do not share personal contact information.'.tr,
              style: const TextStyle(fontSize: 9, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ConversationModel message, bool isMe) {
    final bubbleColor = isMe
        ? AppColors.primary.withValues(alpha: 0.09)
        : AppColors.darkBackground.withValues(alpha: 0.09);
    final textColor = Colors.black87;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
    );

    return GestureDetector(
      onLongPress: () => _showMessageOptionsModal(message, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.repliedToMessageId != null &&
                  message.repliedToMessageId!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: isMe ? AppColors.primary : Colors.blue.shade300,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    message.repliedToMessageContent ??
                        'Replying to a message'.tr,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              _buildMessageContent(message, textColor),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  Constant.dateAndTimeFormatTimestamp(message.createdAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(ConversationModel message, Color textColor) {
    switch (message.messageType) {
      case 'image':
        return GestureDetector(
          onTap: () =>
              Get.to(FullScreenImageViewer(imageUrl: message.url!.url)),
          child: Hero(
            tag: message.url!.url,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: message.url!.url,
                placeholder: (context, url) =>
                    const CupertinoActivityIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ),
        );
      case 'video':
        return GestureDetector(
          onTap: () => Get.to(FullScreenVideoViewer(
              heroTag: message.id.toString(), videoUrl: message.url!.url)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: message.videoThumbnail!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const CupertinoActivityIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.play_arrow, color: Colors.white, size: 40),
              ),
            ],
          ),
        );
      default: // 'text'
        return Text(
          message.message.toString(),
          style: TextStyle(color: textColor, fontSize: 15),
        );
    }
  }

  Widget _buildSuggestedReplies() {
    final suggestions = [
      "Where are you?".tr,
      "I'm here".tr,
      "When will you arrive?".tr,
      "Yes".tr,
      "On my way".tr
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: suggestions.map((text) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: OutlinedButton(
              onPressed: () => _sendMessage(text, null, '', 'text'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.grey.shade300, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontWeight: FontWeight.normal),
              ),
              child: Text(text),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            color: AppColors.primary,
            margin: const EdgeInsets.only(right: 12),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Replying to ${widget.customerName ?? 'Customer'}".tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingToMessage!.message ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 5,
          )
        ],
      ),
      child: Row(
        children: [
          IconButton(
            key: _attachmentButtonKey,
            onPressed: _toggleAttachmentMenu,
            icon: Icon(Icons.add_circle_outline_rounded,
                color: Colors.grey.shade600, size: 28),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _sendMessage(
                    value,
                    null,
                    '',
                    'text',
                    repliedToMessageId: _replyingToMessage?.id,
                    repliedToMessageContent: _replyingToMessage?.message,
                  );
                  _messageController.clear();
                  _cancelReply();
                }
              },
              decoration: InputDecoration(
                hintText: "Type a message...".tr,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            mini: true,
            onPressed: () {
              if (_messageController.text.isNotEmpty) {
                _sendMessage(
                  _messageController.text,
                  null,
                  '',
                  'text',
                  repliedToMessageId: _replyingToMessage?.id,
                  repliedToMessageContent: _replyingToMessage?.message,
                );
                _messageController.clear();
                _cancelReply();
              }
            },
            backgroundColor: AppColors.primary,
            elevation: 1,
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          )
        ],
      ),
    );
  }

  // --- Modals and Dialogs ---

  void _showMessageOptionsModal(ConversationModel data, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (isMe && data.messageType == 'text')
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                  title: Text("Edit".tr),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(data.id!, data.message!);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text("Delete".tr),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteDialog(data.id!);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.reply_outlined, color: Colors.green),
                title: Text("Reply".tr),
                onTap: () {
                  Navigator.pop(context);
                  _startReply(data);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(String messageId) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text("Delete Message".tr),
        content: Text("Are you sure you want to delete this message?".tr),
        actions: [
          CupertinoDialogAction(
            child: Text("Cancel".tr),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text("Delete".tr),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteMessage(messageId);
            },
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String messageId, String currentMessage) {
    final editController = TextEditingController(text: currentMessage);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Edit Message".tr, style: AppTypography.h3(context)),
            const SizedBox(height: 16),
            TextField(
              controller: editController,
              autofocus: true,
              maxLines: null,
              style: AppTypography.input(context),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel".tr,
                      style: TextStyle(color: Colors.grey.shade700)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    if (editController.text.isNotEmpty) {
                      await _editMessage(messageId, editController.text);
                      Navigator.pop(context);
                    } else {
                      ShowToastDialog.showToast("Message cannot be empty".tr);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: Text(
                    "Save".tr,
                    style: AppTypography.buttonlight(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // --- Backend Logic ---

  final ImagePicker _imagePicker = ImagePicker();

  void _sendMessage(
    String message,
    Url? url,
    String videoThumbnail,
    String messageType, {
    String? repliedToMessageId,
    String? repliedToMessageContent,
  }) async {
    // Driver is the sender
    InboxModel inboxModel = InboxModel(
      lastSenderId: widget.driverId,
      customerId: widget.customerId,
      customerName: widget.customerName,
      driverId: widget.driverId,
      driverName: widget.driverName,
      driverProfileImage: widget.driverProfileImage,
      createdAt: Timestamp.now(),
      orderId: widget.orderId,
      customerProfileImage: widget.customerProfileImage,
      lastMessage: messageType == 'text' ? message : "Sent a $messageType".tr,
    );
    await FireStoreUtils.addInBox(inboxModel);

    ConversationModel conversationModel = ConversationModel(
      id: const Uuid().v4(),
      message: message,
      senderId: FireStoreUtils.getCurrentUid(), // Driver's UID
      receiverId: widget.customerId, // Customer's UID
      createdAt: Timestamp.now(),
      url: url,
      orderId: widget.orderId,
      messageType: messageType,
      videoThumbnail: videoThumbnail,
      repliedToMessageId: repliedToMessageId,
      repliedToMessageContent: repliedToMessageContent,
    );

    if (url != null) {
      if (url.mime.contains('image')) {
        conversationModel.message = "Sent an image".tr;
      } else if (url.mime.contains('video')) {
        conversationModel.message = "Sent a video".tr;
      }
    }

    await FireStoreUtils.addChat(conversationModel);

    Timer(const Duration(milliseconds: 300), () {
      if (_controller.hasClients) {
        _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    Map<String, dynamic> playLoad = <String, dynamic>{
      "type": "chat",
      "driverId": widget.driverId,
      "customerId": widget.customerId,
      "orderId": widget.orderId,
    };

    SendNotification.sendOneNotification(
      title: "${widget.driverName} sent you a message".tr,
      body: conversationModel.message.toString(),
      token: widget.token.toString(),
      payload: playLoad,
    );
  }
}
