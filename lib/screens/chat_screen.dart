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
            const CircleAvatar(),
            const SizedBox(width: 10),
            Text(
              widget.receiverDoc['username'],
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
                      return ListTile(
                        tileColor: snapshot.data!.docs[index]['senderId'] ==
                                _auth.currentUser!.uid
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        title: Text(snapshot.data!.docs[index]['message'],
                            textAlign: snapshot.data!.docs[index]['senderId'] ==
                                    _auth.currentUser!.uid
                                ? TextAlign.right
                                : TextAlign.left),
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
                                      'receiverId': widget.receiverDoc.id,
                                      'timestamp': Timestamp.now(),
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
                                        'receiverId': widget.receiverDoc.id,
                                        'timestamp': Timestamp.now(),
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
