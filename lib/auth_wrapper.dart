import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'pages/login_page.dart';
import 'pages/onboarding_page.dart';
import 'main.dart'; // To access MyHomePage

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Securing connection...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<bool>(
            future: authService.isUserOnboarded(),
            builder: (context, onboardSnapshot) {
              if (onboardSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (onboardSnapshot.data == true) {
                return MyHomePage(user: snapshot.data!);
              } else {
                return const OnboardingPage();
              }
            },
          );
        }
        
        return const LoginPage();
      },
    );
  }
}
