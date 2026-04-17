import 'package:admin_thinkink/utils/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

              // Handle errors (e.g., Firestore permission denied)
              if (onboardSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            "Connection Error",
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            onboardSnapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => AuthService().signOut(),
                            child: const Text("SIGN OUT & RETRY"),
                          ),
                        ],
                      ),
                    ),
                  ),
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
