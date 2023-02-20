import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/loading.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      // show drawer
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Drawer')));
                    },
                    icon: const Icon(Icons.menu_rounded),
                  ),
                  const Text('Chats', style: TextStyle(fontSize: 24)),
                ],
              ),
              const SizedBox(height: 20),
              const TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Available Users', style: TextStyle(fontSize: 18)),
              Expanded(
                child: StreamBuilder(
                  stream: _firestore.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Something went wrong');
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    return Row(
                      children: snapshot.data!.docs.map((document) {
                        return Expanded(
                          child: ListTile(
                            title: Text(document['username']),
                            subtitle: Text(document['email']),
                            onTap: () {
                              Navigator.of(context).pushNamed('/chat',
                                  arguments: {'id': document['id']});
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text('Recent Chats', style: TextStyle(fontSize: 18)),
              Expanded(
                child: StreamBuilder(
                  stream: _firestore
                      .collection('users')
                      .doc(_auth.currentUser!.uid)
                      .collection('chats')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Something went wrong');
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    return ListView(
                      children: snapshot.data!.docs.map((document) {
                        return ListTile(
                          title: Text(document['username']),
                          subtitle: Text(document['lastMessage']),
                          onTap: () {
                            Navigator.of(context).pushNamed('/chat',
                                arguments: {'id': document['id']});
                          },
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

// ElevatedButton(
//   onPressed: () async {
//     setState(() => isLoading = true);
//     try {
//       await GoogleSignIn().signOut();
//       await _auth.signOut().then((value) =>
//           Navigator.of(context)
//               .pushReplacementusernamed('/login'));
//     } catch (e) {
//       setState(() => isLoading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('An error occured')));
//       return;
//     }
//   },
//   style: ButtonStyle(
//     shape: MaterialStateProperty.all(
//       RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(25),
//       ),
//     ),
//     minimumSize:
//         MaterialStateProperty.all(const Size(100, 50)),
//     shadowColor:
//         MaterialStateProperty.all(Colors.transparent),
//   ),
//   child: const Text('Logout'),
// ),
