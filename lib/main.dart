import 'package:admin_thinkink/pages/printer_connecting_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_wrapper.dart';
import 'pages/tabs/home_tab.dart';
import 'pages/tabs/wallet_tab.dart';
import 'pages/tabs/pending_tab.dart';
import 'pages/tabs/profile_tab.dart';
import 'utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/printer_service.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
    
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: dotenv.env['FIREBASE_API_KEY'] ?? "",
          authDomain: "${dotenv.env['FIREBASE_PROJECT_ID']}.firebaseapp.com",
          projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? "thinkink-admin",
          storageBucket: "${dotenv.env['FIREBASE_PROJECT_ID']}.firebasestorage.app",
          messagingSenderId: "1071627103248", // Project number from google-services.json
          appId: "1:1071627103248:web:75db1649646b5dc69bbae9", // Placeholder: User should verify this
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Initialization error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrinterService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin ThinkInk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          onPrimary: Colors.white,
          surface: AppColors.surface,
        ),
        
        // Typography Sync
        fontFamily: GoogleFonts.manrope().fontFamily,
        textTheme: GoogleFonts.manropeTextTheme().copyWith(
          displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),

        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.user});
  final User user;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  Map<String, dynamic>? shopData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchShopData();
  }

  Future<void> _fetchShopData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(widget.user.uid).get();
      if (mounted) {
        setState(() {
          shopData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching shop data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> pages = [
      HomeTab(user: widget.user),
      PendingTab(user: widget.user),
      WalletTab(user: widget.user),
      ProfileTab(user: widget.user, shopData: shopData),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
          // 🚀 PROFESSIONAL PRINT ASSISTANT OVERLAY (HP/Canon Style)
          Consumer<PrinterService>(
            builder: (context, service, child) {
              if (!service.isJobActive) return const SizedBox.shrink();
              
              return Container(
                color: Colors.black.withValues(alpha: 0.85),
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: Container(
                    width: 320,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: AppColors.mediumShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.print_rounded, color: AppColors.primaryBlue, size: 48),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          "ThinkInk Print Assistant",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          service.jobStatusMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 32),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: service.jobProgress,
                            backgroundColor: AppColors.border,
                            color: AppColors.primaryBlue,
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue)),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "${(service.jobProgress * 100).toInt()}% TRANSMITTED",
                              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.primaryBlue, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
         
          Consumer<PrinterService>(
            builder: (context, ps, _) => GestureDetector(
              onTap: () {
                if (!ps.isConnected) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterConnectingPage()));
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: ps.isConnected ? AppColors.success.withValues(alpha: 0.9) : AppColors.error.withValues(alpha: 0.9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      ps.isConnected ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ps.isConnected 
                        ? "${ps.primaryPrinter?.toUpperCase()} READY" 
                        : "MACHINE DISCONNECTED - TAP TO LINK",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: kIsWeb || defaultTargetPlatform != TargetPlatform.android ? 10 : 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.primaryBlue,
            unselectedItemColor: AppColors.textTertiary,
            selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11),
            elevation: 8,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "HOME"),
              BottomNavigationBarItem(icon: Icon(Icons.pending_actions_rounded), label: "PENDING"),
              BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: "WALLET"),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "PROFILE"),
            ],
          ),
        ],
      ),
    );
  }
}
