import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../../utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🌐 PREMIUM NAVBAR
            _buildNavbar(),

            // 🚀 HERO SECTION
            _buildHero(context, isDesktop, authService),

            // ✨ FEATURES SECTION
            _buildFeatures(isDesktop),

            // 🦶 FOOTER
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                "ThinkInk Admin",
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primaryBlack, letterSpacing: -0.5),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {}, // Scroll to login or similar
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text("Launch Console"),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isDesktop, AuthService authService) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 100 : 24, vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surface, AppColors.background],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isDesktop 
            ? Row(
                children: [
                  Expanded(flex: 3, child: _buildHeroText()),
                  const SizedBox(width: 80),
                  Expanded(flex: 2, child: _buildLoginCard(context, authService)),
                ],
              )
            : Column(
                children: [
                  _buildHeroText(),
                  const SizedBox(height: 60),
                  _buildLoginCard(context, authService),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildHeroText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
          child: Text(
            "SHOP MANAGER 2026",
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.primaryBlue, letterSpacing: 1.5),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Scale Your Xerox\nBusiness Anywhere.",
          style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w900, height: 1.1, color: AppColors.textPrimary, letterSpacing: -2),
        ),
        const SizedBox(height: 24),
        Text(
          "Connect your printers to our autonomous network. Manage orders, track earnings, and monitor device health in real-time.",
          style: GoogleFonts.manrope(fontSize: 18, color: AppColors.textSecondary, height: 1.6, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context, AuthService authService) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: AppColors.mediumShadow,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Operator Access",
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            "Access your shop dashboard",
            style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () async {
              final user = await authService.signInWithGoogle();
              if (user != null && context.mounted) {
                 // Navigation handled by AuthWrapper
              }
            },
            icon: Image.asset('assets/images/google_logo.png', height: 22),
            label: const Text("Continue with Google"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text("OR", style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
              ),
              Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "By signing in, you agree to the\nThinkInk Terms of Service.",
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(color: AppColors.textTertiary, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures(bool isDesktop) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 100 : 24, vertical: 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text("Modern Features for Modern Shops", style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -1)),
              const SizedBox(height: 60),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _featureItem(Icons.analytics_rounded, "Live Analytics", "Real-time tracking of orders and shop performance."),
                  _featureItem(Icons.print_disabled_rounded, "Remote Error Detection", "Get notified instantly when paper is empty or toner is low."),
                  _featureItem(Icons.qr_code_2_rounded, "Global ID System", "Unique QR identity for your shop across the whole network."),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureItem(IconData icon, String title, String desc) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 32),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Text(desc, style: GoogleFonts.manrope(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(40),
      color: AppColors.background,
      child: Center(
        child: Text(
          "© 2026 ThinkInk Professional Printing Solutions",
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
