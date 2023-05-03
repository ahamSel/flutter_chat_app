import 'dart:convert';

import 'package:chatapp/components/static_vars.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final DocumentSnapshot? receiverDoc;

  const ChatScreen({super.key, required this.receiverDoc});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final messageController = TextEditingController();
  String message = '';

  bool isReceiverDeleted = false;
  String deletedReceiverId = '';

  late final String chatId;

  String senderUsername = '';

  late Stream chatStream;

  Stream<QuerySnapshot> getChatStream() {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection(chatId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    StaticVars.onChatScreen = true;
    if (widget.receiverDoc!.id.contains('_')) {
      isReceiverDeleted = true;
      chatId = widget.receiverDoc!.id;
      deletedReceiverId = chatId.split('_')[0] == _auth.currentUser!.uid
          ? chatId.split('_')[1]
          : chatId.split('_')[0];
    } else {
      chatId = _auth.currentUser!.uid.compareTo(widget.receiverDoc!.id) > 0
          ? '${_auth.currentUser!.uid}_${widget.receiverDoc!.id}'
          : '${widget.receiverDoc!.id}_${_auth.currentUser!.uid}';
    }
    chatStream = getChatStream();
    _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get()
        .then((value) => senderUsername = value['username']);
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 60,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              constraints: const BoxConstraints(),
              onPressed: () {
                StaticVars.onChatScreen = false;
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_rounded),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            const SizedBox(width: 10),
            isReceiverDeleted
                ? const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey,
                  )
                : const CircleAvatar(),
            const SizedBox(width: 10),
            Text(
              isReceiverDeleted
                  ? 'Deleted Account'
                  : widget.receiverDoc!['username'],
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: chatStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error!'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasData) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    reverse: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final isSender = snapshot.data!.docs[index]['senderId'] ==
                          _auth.currentUser!.uid;
                      final message = snapshot.data!.docs[index]['message'];
                      final timestamp = snapshot.data!.docs[index]['timestamp']
                          .toDate()
                          .toString();
                      return GestureDetector(
                        onLongPress: () {
                          if (isSender) {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text(
                                      'What do you want to do with this message?',
                                      style: TextStyle(fontSize: 18)),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Clipboard.setData(
                                            ClipboardData(text: message));
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Copy',
                                          style: TextStyle(fontSize: 16)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _firestore
                                            .collection('chats')
                                            .doc(chatId)
                                            .collection(chatId)
                                            .doc(snapshot.data!.docs[index].id)
                                            .delete();
                                        // update the last message in firestore to the second last message if the deleted message is the last message
                                        if (snapshot.data!.docs.length > 1) {
                                          if (index == 0) {
                                            _firestore
                                                .collection('chats')
                                                .doc(chatId)
                                                .update({
                                              'lastMessage': {
                                                'message': snapshot.data!
                                                    .docs[index + 1]['message'],
                                                'senderId': snapshot
                                                        .data!.docs[index + 1]
                                                    ['senderId'],
                                                'receiverId': snapshot
                                                        .data!.docs[index + 1]
                                                    ['receiverId'],
                                                'timestamp': snapshot
                                                        .data!.docs[index + 1]
                                                    ['timestamp'],
                                              }
                                            });
                                          }
                                        } else {
                                          _firestore
                                              .collection('chats')
                                              .doc(chatId)
                                              .delete();
                                        }
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Delete',
                                          style: TextStyle(fontSize: 16)),
                                    ),
                                  ],
                                );
                              },
                            );
                          } else {
                            Clipboard.setData(ClipboardData(text: message));
                          }
                        },
                        child: Row(
                          mainAxisAlignment: isSender
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            // show the date if the message is sent on a different day (for the sender)
                            if (isSender &&
                                (index == 0 ||
                                    snapshot.data!.docs[index]['timestamp']
                                            .toDate()
                                            .day !=
                                        snapshot
                                            .data!.docs[index - 1]['timestamp']
                                            .toDate()
                                            .day))
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 10, bottom: 5, left: 10, right: 10),
                                child: Text(
                                  DateFormat('MMM d, yyyy').format(snapshot
                                      .data!.docs[index]['timestamp']
                                      .toDate()),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              margin: const EdgeInsets.only(
                                  left: 8, right: 8, top: 4),
                              decoration: BoxDecoration(
                                color: isSender
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[600],
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(isSender ? 16 : 0),
                                  topRight: Radius.circular(isSender ? 0 : 16),
                                  bottomLeft: const Radius.circular(16),
                                  bottomRight: const Radius.circular(16),
                                ),
                              ),
                              constraints: BoxConstraints(
                                maxWidth: size.width * 0.7,
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.end,
                                spacing: 5,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 3, right: 5),
                                    child: Text(
                                      message,
                                      overflow: TextOverflow.visible,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                  ),
                                  Text(
                                    timestamp.substring(11, 16),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // show the date if the message is sent on a different day (for the receiver)
                            if (!isSender &&
                                (index == 0 ||
                                    snapshot.data!.docs[index]['timestamp']
                                            .toDate()
                                            .day !=
                                        snapshot
                                            .data!.docs[index - 1]['timestamp']
                                            .toDate()
                                            .day))
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 10, bottom: 5, left: 10, right: 10),
                                child: Text(
                                  DateFormat('MMM d, yyyy').format(snapshot
                                      .data!.docs[index]['timestamp']
                                      .toDate()),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                }
                return const Center(
                  child: Text('No data'),
                );
              },
            ),
          ),
          Container(
            constraints: const BoxConstraints(
              maxHeight: 100,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: TextField(
              controller: messageController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              onChanged: (value) {
                message = value.trim();
              },
              decoration: InputDecoration(
                fillColor: Colors.white,
                filled: true,
                suffixIconColor: Theme.of(context).primaryColor,
                hintText: 'Enter a message...',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                suffixIcon: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // IconButton(
                      //   onPressed: () {},
                      //   icon: const Icon(Icons.attach_file_rounded, size: 23),
                      //   splashColor: Colors.transparent,
                      //   highlightColor: Colors.transparent,
                      // ),
                      // IconButton(
                      //   onPressed: () {},
                      //   icon: const Icon(Icons.camera_alt_rounded, size: 23),
                      //   splashColor: Colors.transparent,
                      //   highlightColor: Colors.transparent,
                      // ),
                      const VerticalDivider(
                        width: 10,
                        endIndent: 10,
                        indent: 10,
                        color: Colors.black,
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, size: 23),
                        onPressed: () {
                          if (messageController.text.trim().isEmpty) return;
                          messageController.clear();
                          _firestore.runTransaction((transaction) async => {
                                transaction.set(
                                  _firestore
                                      .collection('chats')
                                      .doc(chatId)
                                      .collection(chatId)
                                      .doc(),
                                  {
                                    'message': message,
                                    'senderId': _auth.currentUser!.uid,
                                    'receiverId': isReceiverDeleted
                                        ? deletedReceiverId
                                        : widget.receiverDoc!.id,
                                    'timestamp': FieldValue.serverTimestamp(),
                                  },
                                ),
                                transaction.set(
                                  _firestore.collection('chats').doc(chatId),
                                  {
                                    'users': [
                                      _auth.currentUser!.uid,
                                      widget.receiverDoc!.id
                                    ],
                                    'lastMessage': {
                                      'message': message,
                                      'senderId': _auth.currentUser!.uid,
                                      'receiverId': isReceiverDeleted
                                          ? deletedReceiverId
                                          : widget.receiverDoc!.id,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    }
                                  },
                                ),
                              });
                          if (isReceiverDeleted) return;
                          http.post(
                            Uri.parse('https://fcm.googleapis.com/fcm/send'),
                            headers: {
                              'Content-Type': 'application/json',
                              'Authorization': // change key
                                  'key=server-key'
                            },
                            body: jsonEncode(
                              {
                                'priority': 'high',
                                'to': widget.receiverDoc!['fcmToken'],
                                'notification': {
                                  'icon': '@drawable/ic_notif_chat',
                                  'title': senderUsername,
                                  'body': message,
                                },
                                'data': {
                                  'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                                  'senderId': _auth.currentUser!.uid,
                                  'status': 'done',
                                },
                              },
                            ),
                          );
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                    ],
                  ),
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
