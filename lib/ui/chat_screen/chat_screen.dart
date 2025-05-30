import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/ChatVideoContainer.dart';
import 'package:driver/model/conversation_model.dart';
import 'package:driver/model/inbox_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/typography.dart';
import 'package:driver/ui/chat_screen/FullScreenImageViewer.dart';
import 'package:driver/ui/chat_screen/FullScreenVideoViewer.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/firebase_pagination/src/firestore_pagination.dart';
import 'package:driver/widget/firebase_pagination/src/models/view_type.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
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
    Key? key,
    this.orderId,
    this.customerId,
    this.customerName,
    this.driverName,
    this.driverId,
    this.customerProfileImage,
    this.driverProfileImage,
    this.token,
  }) : super(key: key);

  @override
  State<ChatScreens> createState() => _ChatScreensState();
}

class _ChatScreensState extends State<ChatScreens> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _controller = ScrollController();
  ConversationModel? _replyingToMessage; // Track the message being replied to

  @override
  void initState() {
    super.initState();
    if (_controller.hasClients) {
      Timer(const Duration(milliseconds: 500),
          () => _controller.jumpTo(_controller.position.maxScrollExtent));
    }
  }

  void _startReply(ConversationModel message) {
    setState(() {
      _replyingToMessage = message;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  void _showDeleteDialog(String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Delete Message".tr,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                "Are you sure you want to delete this message?".tr,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[800]),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel".tr,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      await _deleteMessage(messageId);
                      Navigator.pop(context);
                    },
                    child: Text(
                      "Delete",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(String messageId, String currentMessage) {
    TextEditingController _editController = TextEditingController(text: currentMessage);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
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
              Text(
                "Edit Message".tr,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _editController,
                decoration: InputDecoration(
                  hintText: "Enter new message".tr,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancel".tr,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      if (_editController.text.isNotEmpty) {
                        await _editMessage(messageId, _editController.text);
                        Navigator.pop(context);
                      } else {
                        ShowToastDialog.showToast("Message cannot be empty".tr);
                      }
                    },
                    child: Text(
                      "Save".tr,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection(CollectionName.chat)
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
          .collection(CollectionName.chat)
          .doc(widget.orderId)
          .collection('thread')
          .doc(messageId)
          .update({'message': newMessage});
      ShowToastDialog.showToast("Message updated successfully".tr);
    } catch (e) {
      ShowToastDialog.showToast("Failed to update message: $e".tr);
    }
  }

  void _showMessageOptionsModal(ConversationModel data, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "Message Options".tr,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color.fromARGB(221, 59, 59, 59),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color.fromARGB(255, 223, 223, 223)),
              if (isMe && data.messageType == 'text')
                ListTile(
                  leading: Icon(Icons.edit, color: AppColors.primary),
                  title: Text("Edit".tr, style: GoogleFonts.poppins(fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(data.id!, data.message!);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text("Delete".tr, style: GoogleFonts.poppins(fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteDialog(data.id!);
                  },
                ),
              ListTile(
                leading: Icon(Icons.reply, color: AppColors.primary),
                title: Text("Reply".tr, style: GoogleFonts.poppins(fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor:  Colors.white,
        elevation: 0.2,
        backgroundColor:  Colors.white,
        title: Row(
          children: [
            ClipOval(
              child: CachedNetworkImage(
                width: 40,
                height: 40,
                imageUrl: widget.customerProfileImage.toString(),
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
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customerName ?? 'Customer',
                  style: AppTypography.boldLabel(context),
                ),
                Text(
                  '#${widget.orderId}',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color:  Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: InkWell(
          onTap: () => Get.back(),
          child: Icon(
            Icons.arrow_back,
            color:  Colors.black,
          ),
        ),
      ),
      backgroundColor:  Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() {});
                },
                child: FirestorePagination(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, documentSnapshots, index) {
                    ConversationModel inboxModel = ConversationModel.fromJson(documentSnapshots[index].data() as Map<String, dynamic>);
                    return chatItemView(inboxModel.senderId == FireStoreUtils.getCurrentUid(), inboxModel);
                  },
                  onEmpty: Center(child: Text("No Conversion found".tr, style: GoogleFonts.poppins())),
                  query: FirebaseFirestore.instance
                      .collection(CollectionName.chat)
                      .doc(widget.orderId)
                      .collection("thread")
                      .orderBy('createdAt', descending: false),
                  viewType: ViewType.list,
                  isLive: true,
                ),
              ),
            ),
            if (_replyingToMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:  Colors.grey.shade100,
                  border: Border(top: BorderSide(color:  Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Replying to ${widget.customerName ?? 'Customer'}",
                            style: AppTypography.boldLabel(context),
                          ),
                          Text(
                            _replyingToMessage!.message ?? '',
                            style: AppTypography.smBoldLabel(context).copyWith(color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color:  Colors.grey),
                      onPressed: _cancelReply,
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color:  Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color:  Colors.white, width: 1),
              ),
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 4.0),
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: IconButton(
                          color: Colors.white,
                          onPressed: _onCameraClick,
                          icon: const Icon(Icons.camera_alt, size: 18),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          textInputAction: TextInputAction.send,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          controller: _messageController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.only(left: 10, top: 8),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            disabledBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(30)),
                              borderSide: BorderSide(color: Colors.transparent),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(30)),
                              borderSide: BorderSide(color: Colors.transparent),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(30)),
                              borderSide: BorderSide(color: Colors.transparent),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(30)),
                              borderSide: BorderSide(color: Colors.transparent),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(30)),
                              borderSide: BorderSide(color: Colors.transparent),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () async {
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
                                  setState(() {});
                                } else {
                                  ShowToastDialog.showToast("Please enter text".tr);
                                }
                              },
                              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                            ),
                            hintText: 'Start typing ...'.tr,
                            hintStyle: AppTypography.input(context).copyWith(color: Colors.grey[700]),
                          ),
                          style: GoogleFonts.poppins(
                            color:  Colors.black,
                          ),
                          onSubmitted: (value) async {
                            if (_messageController.text.isNotEmpty) {
                              _sendMessage(
                                _messageController.text,
                                null,
                                '',
                                'text',
                                repliedToMessageId: _replyingToMessage?.id,
                                repliedToMessageContent: _replyingToMessage?.message,
                              );
                              Timer(
                                  const Duration(milliseconds: 500),
                                  () => _controller.jumpTo(_controller.position.maxScrollExtent));
                              _messageController.clear();
                              _cancelReply();
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget chatItemView(bool isMe, ConversationModel data) {

    return GestureDetector(
      onTap: () {
        _showMessageOptionsModal(data, isMe);
      },
      child: Container(
        padding: const EdgeInsets.only(left: 15, right: 15, top: 10, bottom: 10),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (data.repliedToMessageId != null && data.repliedToMessageId!.isNotEmpty)
              Container(
                margin: EdgeInsets.only(bottom: 4, left: isMe ? 50 : 0, right: isMe ? 0 : 50),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:  Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color:  Colors.grey.shade300),
                ),
                child: Text(
                  data.repliedToMessageContent ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color:  Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            isMe
                ? Align(
                    alignment: Alignment.topRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (data.messageType == "text")
                          Container(
                            decoration: BoxDecoration(
                              color:  AppColors.primary,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(10),
                                bottomLeft: Radius.circular(10),
                                   bottomRight: Radius.circular(10),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Text(
                              data.message.toString(),
                              style:  AppTypography.boldLabel(context).copyWith(color: Colors.white),
                            ),
                          )
                        else if (data.messageType == "image")
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(10),
                                bottomLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Get.to(FullScreenImageViewer(imageUrl: data.url!.url));
                                    },
                                    child: Hero(
                                      tag: data.url!.url,
                                      child: CachedNetworkImage(
                                        imageUrl: data.url!.url,
                                        placeholder: (context, url) => Constant.loader(context),
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          FloatingActionButton(
                            mini: true,
                            heroTag: data.id,
                            onPressed: () {
                              Get.to(FullScreenVideoViewer(
                                heroTag: data.id.toString(),
                                videoUrl: data.url!.url,
                              ));
                            },
                            child: const Icon(Icons.play_arrow, color: Colors.white),
                          ),
                        const SizedBox(height: 2),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                           
                            Text(
                              Constant.dateAndTimeFormatTimestamp(data.createdAt),
                              style:  AppTypography.timeLabel(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              
                              if (data.messageType == "text")
                                Container(
                                  decoration: BoxDecoration(
                                    color:  Colors.grey.shade300,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      topRight: Radius.circular(10),
                                      bottomRight: Radius.circular(10),
                                         bottomLeft: Radius.circular(10),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Text(
                                    data.message.toString(),
                                     style:  AppTypography.boldLabel(context),
                                  ),
                                )
                              else if (data.messageType == "image")
                                ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      topRight: Radius.circular(10),
                                      bottomRight: Radius.circular(10),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            Get.to(FullScreenImageViewer(imageUrl: data.url!.url));
                                          },
                                          child: Hero(
                                            tag: data.url!.url,
                                            child: CachedNetworkImage(
                                              imageUrl: data.url!.url,
                                              placeholder: (context, url) => Constant.loader(context),
                                              errorWidget: (context, url, error) => const Icon(Icons.error),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                FloatingActionButton(
                                  mini: true,
                                  heroTag: data.id,
                                  onPressed: () {
                                    Get.to(FullScreenVideoViewer(
                                      heroTag: data.id.toString(),
                                      videoUrl: data.url!.url,
                                    ));
                                  },
                                  child: const Icon(Icons.play_arrow),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Constant.dateAndTimeFormatTimestamp(data.createdAt),
                         style:  AppTypography.timeLabel(context),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(String message, Url? url, String videoThumbnail, String messageType, {String? repliedToMessageId, String? repliedToMessageContent}) async {
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
      lastMessage: _messageController.text,
    );

    await FireStoreUtils.addInBox(inboxModel);

    ConversationModel conversationModel = ConversationModel(
      id: const Uuid().v4(),
      message: message,
      senderId: FireStoreUtils.getCurrentUid(),
      receiverId: widget.customerId,
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
        conversationModel.message = "sent an image";
      } else if (url.mime.contains('video')) {
        conversationModel.message = "sent a video";
      } else if (url.mime.contains('audio')) {
        conversationModel.message = "sent a voice message";
      }
    }

    await FireStoreUtils.addChat(conversationModel);

    Map<String, dynamic> playLoad = <String, dynamic>{
      "type": "chat",
      "driverId": widget.driverId,
      "customerId": widget.customerId,
      "orderId": widget.orderId,
    };

    SendNotification.sendOneNotification(
      title: "${widget.driverName} ${messageType == "image" ? "sent an image to you" : messageType == "video" ? "sent a video to you" : "sent a message to you"}",
      body: conversationModel.message.toString(),
      token: widget.token.toString(),
      payload: playLoad,
    );
  }

  final ImagePicker _imagePicker = ImagePicker();

  void _onCameraClick() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Send Media".tr,
                      style:  AppTypography.headers(context),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: const Color.fromARGB(255, 38, 38, 38),
                        fixedSize: const Size(30, 30),
                        minimumSize: const Size(30, 30),
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, endIndent: 10, indent: 10, color: Color.fromARGB(255, 231, 231, 231)),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.3,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _buildMediaOption(
                    context,
                    icon: Icons.photo_library_rounded,
                    label: "Choose image from gallery".tr,
                    color: AppColors.primary,
                    onTap: () async {
                      Navigator.pop(context);
                      XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        Url url = await Constant().uploadChatImageToFireStorage(File(image.path));
                        _sendMessage('', url, '', 'image');
                      }
                    },
                  ),
                  _buildMediaOption(
                    context,
                    icon: Icons.video_library_rounded,
                    label: "Choose video from gallery".tr,
                    color: AppColors.tabBarSelected,
                    onTap: () async {
                      Navigator.pop(context);
                      XFile? galleryVideo = await _imagePicker.pickVideo(source: ImageSource.gallery);
                      if (galleryVideo != null) {
                        ChatVideoContainer? videoContainer = await Constant().uploadChatVideoToFireStorage(File(galleryVideo.path));
                        if (videoContainer != null) {
                          _sendMessage('', videoContainer.videoUrl, videoContainer.thumbnailUrl, 'video');
                        } else {
                          ShowToastDialog.showToast("Message sent failed");
                        }
                      }
                    },
                  ),
                  _buildMediaOption(
                    context,
                    icon: Icons.camera_alt_rounded,
                    label: "Take a Photo".tr,
                    color: AppColors.tabBarSelected,
                    onTap: () async {
                      Navigator.pop(context);
                      XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
                      if (image != null) {
                        Url url = await Constant().uploadChatImageToFireStorage(File(image.path));
                        _sendMessage('', url, '', 'image');
                      }
                    },
                  ),
                  _buildMediaOption(
                    context,
                    icon: Icons.videocam_rounded,
                    label: "Record video".tr,
                    color: AppColors.primary,
                    onTap: () async {
                      Navigator.pop(context);
                      XFile? recordedVideo = await _imagePicker.pickVideo(source: ImageSource.camera);
                      if (recordedVideo != null) {
                        ChatVideoContainer? videoContainer = await Constant().uploadChatVideoToFireStorage(File(recordedVideo.path));
                        if (videoContainer != null) {
                          _sendMessage('', videoContainer.videoUrl, videoContainer.thumbnailUrl, 'video');
                        } else {
                          ShowToastDialog.showToast("Message sent failed");
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style:  AppTypography.boldLabel(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}