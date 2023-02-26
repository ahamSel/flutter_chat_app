import 'package:chatapp/screens/start_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/loading.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool isLoading = false;

  final _usernameFormKey = GlobalKey<FormFieldState>();

  Stream<QuerySnapshot> getOtherUsers() {
    return _firestore
        .collection('users')
        .where(FieldPath.documentId, isNotEqualTo: _auth.currentUser?.uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserChats() {
    return _firestore
        .collection('chats')
        .where('users', arrayContains: _auth.currentUser?.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          child: Column(
            children: [
              const SizedBox(height: 50),
              const CircleAvatar(
                radius: 50,
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder(
                    stream: _firestore
                        .collection('users')
                        .doc(_auth.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Error loading username');
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (snapshot.data?.data() == null) {
                        return const SizedBox();
                      }
                      return TextFormField(
                        key: _usernameFormKey,
                        initialValue: snapshot.data!['username'],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (value) {
                          value = value!.trim();
                          if (value != snapshot.data!['username']) {
                            if (value.length < 3 || value.length > 12) {
                              return "Username must 3 to 12 characters long";
                            } else if (value.contains(' ')) {
                              return "Username cannot contain spaces";
                            }
                          }
                          return null;
                        },
                        onFieldSubmitted: (value) async {
                          value = value.trim();
                          if (!_usernameFormKey.currentState!.validate() ||
                              value == snapshot.data!['username']) return;
                          try {
                            await _firestore
                                .runTransaction((transaction) => transaction
                                        .get(_firestore
                                            .collection('info')
                                            .doc('unicity'))
                                        .then((unicityDoc) async {
                                      final QuerySnapshot usernamesSnapshot =
                                          await _firestore
                                              .collection('users')
                                              .where('username',
                                                  isEqualTo: value)
                                              .get();
                                      if (usernamesSnapshot.docs.isNotEmpty) {
                                        setState(() => isLoading = false);
                                        Future.delayed(
                                            const Duration(),
                                            () => showDialog(
                                                context: context,
                                                builder: (context) {
                                                  return AlertDialog(
                                                    content: const Text(
                                                        'This username is already in use by another account.'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                        child: const Text('Ok',
                                                            style: TextStyle(
                                                                fontSize: 16)),
                                                      ),
                                                    ],
                                                  );
                                                }));
                                        return false;
                                      }
                                      transaction.update(unicityDoc.reference,
                                          {'counter': FieldValue.increment(1)});
                                      await _firestore
                                          .collection('users')
                                          .doc(_auth.currentUser!.uid)
                                          .update({
                                        'username': value,
                                      });
                                      return true;
                                    }))
                                .then((success) {
                              if (success) {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text(
                                            'Username successfully updated!',
                                            style: TextStyle(
                                                fontWeight: FontWeight.normal)),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('Ok',
                                                style: TextStyle(fontSize: 16)),
                                          ),
                                        ],
                                      );
                                    });
                              } else {
                                _firestore
                                    .collection('users')
                                    .doc(_auth.currentUser!.uid)
                                    .get()
                                    .then((userDoc) {
                                  if (userDoc.data()!['username'] == value) {
                                    _firestore
                                        .collection('users')
                                        .doc(_auth.currentUser!.uid)
                                        .update({
                                      'username': snapshot.data!['username'],
                                    });
                                  }
                                });
                              }
                            });
                          } catch (e) {
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    content: const Text(
                                        'An error occured while updating your username.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Ok',
                                            style: TextStyle(fontSize: 16)),
                                      ),
                                    ],
                                  );
                                });
                            return;
                          }
                        },
                        decoration: const InputDecoration(
                          suffixIcon: Icon(Icons.edit),
                        ),
                      );
                    }),
              ),
              const SizedBox(height: 20),
              ListTile(
                onTap: () async {
                  setState(() => isLoading = true);
                  _scaffoldKey.currentState!.closeDrawer();
                  try {
                    await _auth.signOut().then((value) => Navigator.of(context)
                        .pushReplacement(MaterialPageRoute(
                            builder: (context) => const StartScreen())));
                  } catch (e) {
                    setState(() => isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('An error occured')));
                    return;
                  }
                },
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout', style: TextStyle(fontSize: 16)),
              ),
              const Spacer(),
              ListTile(
                onTap: () async {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Delete Account'),
                          content: const Text(
                              'Are you sure you want to delete your account?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Cancel',
                                  style: TextStyle(fontSize: 16)),
                            ),
                            TextButton(
                              onPressed: () async {
                                setState(() => isLoading = true);
                                Navigator.of(context).pop();
                                _scaffoldKey.currentState!.closeDrawer();
                                try {
                                  await _firestore
                                      .collection('users')
                                      .doc(_auth.currentUser!.uid)
                                      .delete()
                                      .then((value) =>
                                          _auth.currentUser!.delete())
                                      .then((value) => ScaffoldMessenger.of(
                                              _scaffoldKey.currentContext!)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('Account deleted!'))))
                                      .then((value) => Navigator.of(
                                              _scaffoldKey.currentContext!)
                                          .pushReplacement(MaterialPageRoute(
                                              builder: (context) =>
                                                  const StartScreen())));
                                } catch (e) {
                                  setState(() => isLoading = false);
                                  ScaffoldMessenger.of(
                                          _scaffoldKey.currentContext!)
                                      .showSnackBar(const SnackBar(
                                          content: Text('An error occured')));
                                  return;
                                }
                              },
                              child: const Text('Delete',
                                  style: TextStyle(fontSize: 16)),
                            ),
                          ],
                        );
                      });
                },
                leading: const Icon(Icons.delete_rounded),
                title: const Text('Delete Account',
                    style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          _scaffoldKey.currentState!.openDrawer();
                        },
                        icon: const Icon(Icons.menu_rounded),
                      ),
                      const SizedBox(width: 10),
                      const Text('Chats', style: TextStyle(fontSize: 24)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child:
                        Text('Available Users', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 15),
                  StreamBuilder(
                    stream: getOtherUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Something went wrong');
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: snapshot.data!.docs.map((document) {
                            return InkWell(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) =>
                                        ChatScreen(receiverDoc: document)));
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                child: Column(
                                  children: [
                                    const CircleAvatar(
                                      radius: 35,
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: 70,
                                      child: Text(document['username'],
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 16)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Recent Chats', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: StreamBuilder(
                      stream: getUserChats(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('Something went wrong');
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('No recent chats found.'),
                          );
                        }
                        return ListView(
                          children: snapshot.data!.docs.map((chatDoc) {
                            final otherUserId =
                                chatDoc['users'][0] == _auth.currentUser!.uid
                                    ? chatDoc['users'][1]
                                    : chatDoc['users'][0];
                            final lastMessageInfo = chatDoc['lastMessage'];
                            final lastMessage = lastMessageInfo['message'];
                            final timestamp = lastMessageInfo['timestamp']
                                .toDate()
                                .toString();
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: FutureBuilder(
                                  future: _firestore
                                      .collection('users')
                                      .doc(otherUserId)
                                      .get(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return const Center(
                                          child: Text('Error loading chat'));
                                    }
                                    if (snapshot.data != null) {
                                      if (snapshot.data!.exists) {
                                        return InkWell(
                                          onTap: () {
                                            Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        ChatScreen(
                                                            receiverDoc:
                                                                snapshot
                                                                    .data)));
                                          },
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 20),
                                              const CircleAvatar(
                                                radius: 35,
                                              ),
                                              const SizedBox(width: 10),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      snapshot
                                                          .data!['username'],
                                                      style: const TextStyle(
                                                          fontSize: 16)),
                                                  const SizedBox(height: 5),
                                                  SizedBox(
                                                    width: 200,
                                                    child: Text(
                                                      "${lastMessageInfo['senderId'] == _auth.currentUser!.uid ? 'You: ' : ''}$lastMessage",
                                                      style: const TextStyle(
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          fontSize: 14),
                                                      maxLines: 2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 15),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                        timestamp.substring(
                                                            11, 16),
                                                        style: const TextStyle(
                                                            fontSize: 14)),
                                                    const SizedBox(height: 5),
                                                    Text(
                                                        timestamp.substring(
                                                            0, 10),
                                                        style: const TextStyle(
                                                            fontSize: 8.5)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      } else {
                                        return InkWell(
                                          onTap: () {
                                            Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        ChatScreen(
                                                            receiverDoc:
                                                                chatDoc)));
                                          },
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 20),
                                              const CircleAvatar(
                                                radius: 35,
                                                backgroundColor: Colors.grey,
                                              ),
                                              const SizedBox(width: 10),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text('Deleted Account',
                                                      style: TextStyle(
                                                          fontSize: 16)),
                                                  const SizedBox(height: 5),
                                                  SizedBox(
                                                    width: 200,
                                                    child: Text(
                                                      "${lastMessageInfo['senderId'] == _auth.currentUser!.uid ? 'You: ' : ''}$lastMessage",
                                                      style: const TextStyle(
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          fontSize: 14),
                                                      maxLines: 2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 20),
                                                child: Text(timestamp,
                                                    style: const TextStyle(
                                                        fontSize: 14)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }
                                    return const SizedBox.shrink();
                                  }),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading) const Loading(),
          ],
        ));
  }
}
