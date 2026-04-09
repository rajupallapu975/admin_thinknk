import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'models/app_user.dart';
import 'services/auth_service.dart';
import 'pages/login_page.dart';
import 'pages/onboarding_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // If a user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          
          return FutureBuilder<bool>(
            future: authService.isUserOnboarded(),
            builder: (context, onboardSnapshot) {
              // While checking onboarding status
              if (onboardSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // If user is NOT onboarded, show registration page
              if (onboardSnapshot.data == false) {
                return const OnboardingPage();
              }

              // Normal flow: User is logged in and onboarded
              return MyHomePage(
                user: AppUser(
                  uid: user.uid,
                  displayName: user.displayName,
                  email: user.email,
                  photoURL: user.photoURL,
                ),
              );
            },
          );
        }

        // If not logged in, show the login page
        return const LoginPage();
      },
    );
  }
}
