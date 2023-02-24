import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final dynamic receiverDoc;

  const ChatScreen({super.key, required this.receiverDoc});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String message = '';

  bool isReceiverDeleted = false;
  String deletedReceiverId = '';

  late final String chatId;

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
    if (widget.receiverDoc.id.contains('_')) {
      isReceiverDeleted = true;
      chatId = widget.receiverDoc.id;
      deletedReceiverId = chatId.split('_')[0] == _auth.currentUser!.uid
          ? chatId.split('_')[1]
          : chatId.split('_')[0];
      return;
    }
    chatId = _auth.currentUser!.uid.compareTo(widget.receiverDoc.id) > 0
        ? '${_auth.currentUser!.uid}_${widget.receiverDoc.id}'
        : '${widget.receiverDoc.id}_${_auth.currentUser!.uid}';
  }

  @override
  Widget build(BuildContext context) {
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
                  : widget.receiverDoc['username'],
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: StreamBuilder(
              stream: getChatStream(),
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
                    reverse: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final isSender = snapshot.data!.docs[index]['senderId'] ==
                          _auth.currentUser!.uid;
                      final message = snapshot.data!.docs[index]['message'];
                      final timestamp = snapshot.data!.docs[index]['timestamp']
                          .toDate()
                          .toString()
                          .substring(11, 16);
                      return Row(
                        mainAxisAlignment: isSender
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
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
                              maxWidth: MediaQuery.of(context).size.width * 0.8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  message,
                                  overflow: TextOverflow.visible,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  timestamp,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: const Color(0xFFFAFAFA),
              padding: const EdgeInsets.all(10),
              child: TextField(
                onChanged: (value) => message = value.trim(),
                decoration: InputDecoration(
                  fillColor: Colors.white,
                  filled: true,
                  suffixIconColor: Theme.of(context).primaryColor,
                  hintText: 'Enter a message...',
                  suffixIcon: SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.attach_file_rounded),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.camera_alt_rounded),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        const VerticalDivider(
                          width: 10,
                          endIndent: 10,
                          indent: 10,
                          color: Colors.black,
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded),
                          onPressed: () {
                            if (message.isEmpty) return;
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
                                          : widget.receiverDoc.id,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    },
                                  ),
                                  transaction.set(
                                    _firestore.collection('chats').doc(chatId),
                                    {
                                      'users': [
                                        _auth.currentUser!.uid,
                                        widget.receiverDoc.id
                                      ],
                                      'lastMessage': {
                                        'message': message,
                                        'senderId': _auth.currentUser!.uid,
                                        'receiverId': isReceiverDeleted
                                            ? deletedReceiverId
                                            : widget.receiverDoc.id,
                                        'timestamp':
                                            FieldValue.serverTimestamp(),
                                      }
                                    },
                                  ),
                                });
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
          ),
        ],
      ),
    );
  }
}
