import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/loading.dart';
import 'home_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  bool isLoading = false, isObscure = true;

  late String _username;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text("Welcome!",
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w500,
                        )),
                    const SizedBox(height: 100),
                    TextFormField(
                      validator: (value) {
                        value = value!.trim();
                        if (value.isNotEmpty) {
                          if (value.length < 3 || value.length > 12) {
                            return "Username must be between 3 and 12 characters if it's not empty";
                          } else if (value.contains(' ')) {
                            return "Username cannot contain spaces if it's not empty";
                          }
                        }
                        return null;
                      },
                      onSaved: (value) => _username = value!.trim(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        labelText: 'Enter a username (optional)',
                      ),
                    ),
                    const SizedBox(height: 35),
                    ElevatedButton(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        _formKey.currentState!.save();
                        setState(() => isLoading = true);
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
                                                isEqualTo: _username)
                                            .get();
                                    if (usernamesSnapshot.docs.isNotEmpty) {
                                      setState(() => isLoading = false);
                                      Future.delayed(
                                          const Duration(),
                                          () => ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'This username is already in use by another account.'))));
                                      return false;
                                    }
                                    transaction.update(unicityDoc.reference,
                                        {'counter': FieldValue.increment(1)});
                                    await _auth.signInAnonymously().then(
                                        (value) => _firestore
                                                .collection('users')
                                                .doc(value.user!.uid)
                                                .set({
                                              'username': _username.isEmpty
                                                  ? 'Guest-${unicityDoc['counter'] + 1}'
                                                  : _username,
                                              'createdAt': Timestamp.now(),
                                            }));
                                    return true;
                                  }))
                              .then((success) {
                            if (success) {
                              Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const HomeScreen()));
                            } else if (_auth.currentUser != null) {
                              _firestore
                                  .collection('users')
                                  .doc(_auth.currentUser!.uid)
                                  .delete()
                                  .then((value) => _auth.currentUser!.delete());
                            }
                          });
                        } catch (error) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Something went wrong!')));
                          return;
                        }
                      },
                      style: ButtonStyle(
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        minimumSize:
                            MaterialStateProperty.all(const Size(100, 50)),
                        shadowColor:
                            MaterialStateProperty.all(Colors.transparent),
                      ),
                      child: const Text('Start Chatting',
                          style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isLoading) const Loading(),
      ],
    ));
  }
}
