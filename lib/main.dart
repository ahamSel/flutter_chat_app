import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/password_reset_screen.dart';

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
          '/login': (context) => const LoginScreen(),
          '/password-reset': (context) => const PasswordResetScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/home': (context) => const HomeScreen(),
        },
        title: 'Chat App',
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
                  ? const SignUpScreen()
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
