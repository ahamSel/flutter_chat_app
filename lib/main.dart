import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'screens/start_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Future<FirebaseApp> _fireInit = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  MyApp({super.key});

  // This widget is the root the application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        routes: {
          '/start': (context) => const StartScreen(),
          '/home': (context) => const HomeScreen(),
          '/chat': (context) => const ChatScreen(),
        },
        title: 'Chat App',
        scrollBehavior: const ScrollBehavior().copyWith(
          // Disable overscroll glow effect
          overscroll: false,
        ),
        theme: ThemeData(
          primarySwatch: Colors.indigo,
        ),
        home: FutureBuilder(
          future: _fireInit,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Error!',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.done) {
              return FirebaseAuth.instance.currentUser == null
                  ? const StartScreen()
                  : const HomeScreen();
            }
            return const Scaffold(
              body: Center(
                child: Text(
                  'Loading...',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ));
  }
}
