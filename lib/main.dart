import 'package:admin_thinkink/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_wrapper.dart';
import 'pages/tabs/home_tab.dart';
import 'pages/tabs/wallet_tab.dart';
import 'pages/tabs/pending_tab.dart';
import 'pages/tabs/history_tab.dart';
import 'pages/tabs/profile_tab.dart';
import 'pages/tabs/insights_tab.dart';
import 'utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/printer_service.dart';
import 'models/app_user.dart';
import 'package:flutter/foundation.dart';
import 'services/history_service.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  
  try {
    await dotenv.load(fileName: ".env");
    
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: dotenv.env['FIREBASE_API_KEY'] ?? "AIzaSyCG9N9vDUPmWyId1ZgkiPa7O5vXLp-2l1M",
          authDomain: "thinkink-admin.firebaseapp.com",
          projectId: "thinkink-admin",
          storageBucket: "thinkink-admin.firebasestorage.app",
          messagingSenderId: "1071627103248", 
          appId: "1:1071627103248:web:a67da5bcbf4d1ad29bae95", 
        ),
      );
    } else {
      await Firebase.initializeApp();
    }

    // Initialize PSFC as a secondary app
    try {
      await Firebase.initializeApp(
        name: "psfc",
        options: FirebaseOptions(
           apiKey: dotenv.env['PSFC_API_KEY'] ?? "AIzaSyDhrCs4sKAYt7jr9OQMB1jt22CuOOsGi4E",
           authDomain: "psfc-43b5a.firebaseapp.com",
           projectId: "psfc-43b5a",
           storageBucket: "psfc-43b5a.firebasestorage.app",
           messagingSenderId: "52763236709", 
           appId: "1:52763236709:web:ccc19f87fcfdc4dc37e98c", 
        ),
      );
      debugPrint("🚀 PSFC Secondary App Initialized");
    } catch (e) {
      debugPrint("⚠️ PSFC Init Error (likely already initialized): $e");
    }
  } catch (e) {
    debugPrint("Initialization error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrinterService()),
        ChangeNotifierProvider(create: (_) => HistoryService()..init()),
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
  final AppUser user;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  Map<String, dynamic>? shopData;
  bool _isLoading = true;
  late PageController _pageController;
  List<Widget>? _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _fetchShopData();
    
    // 🎧 Initialize Global Notification Captain
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GlobalNotificationService().init(context, widget.user.uid);
      
      // 🕵️ Start tracking orders for local history preservation
      Provider.of<HistoryService>(context, listen: false).startListening(widget.user.uid);
      
      final printerService = Provider.of<PrinterService>(context, listen: false);
      printerService.addListener(() {
        if (!mounted) return;
        if (printerService.isJobActive && _selectedIndex != 1) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted && _selectedIndex != 1) _onItemTapped(1);
           });
        }
      });
    });
  }

  void _initializePages() {
    _pages = [
      HomeTab(user: widget.user),
      PendingTab(user: widget.user),
      HistoryTab(user: widget.user),
      InsightsTab(user: widget.user),
      WalletTab(user: widget.user),
      ProfileTab(user: widget.user, shopData: shopData),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchShopData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(widget.user.uid).get();
      if (mounted) {
        setState(() {
          shopData = doc.data();
          _initializePages(); // Initialize pages after data is fetched
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching shop data: $e");
      if (mounted) {
        setState(() {
          _initializePages(); // Still initialize with null data
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading shop: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(label: "RETRY", textColor: Colors.white, onPressed: _fetchShopData),
          ),
        );
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width > 900;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          _onItemTapped(0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Row(
              children: [
                if (isWide) 
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onItemTapped,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: AppColors.surface,
                    selectedIconTheme: const IconThemeData(color: AppColors.primaryBlue),
                    unselectedIconTheme: const IconThemeData(color: AppColors.textTertiary),
                    selectedLabelTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.primaryBlue),
                    unselectedLabelTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11, color: AppColors.textTertiary),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Image.asset("assets/images/captain_logo.png", width: 50),
                    ),
                    destinations: const [
                      NavigationRailDestination(icon: Icon(Icons.home_filled), label: Text("HOME")),
                      NavigationRailDestination(icon: Icon(Icons.pending_actions_rounded), label: Text("PENDING")),
                      NavigationRailDestination(icon: Icon(Icons.history_rounded), label: Text("HISTORY")),
                      NavigationRailDestination(icon: Icon(Icons.insights_rounded), label: Text("INSIGHTS")),
                      NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_rounded), label: Text("WALLET")),
                      NavigationRailDestination(icon: Icon(Icons.person_rounded), label: Text("PROFILE")),
                    ],
                  ),
                
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWide ? 1200 : double.infinity),
                      child: Scaffold(
                        appBar: isWide ? null : AppBar(
                          backgroundColor: Colors.transparent,
                          title: Row(
                            children: [
                              Image.asset("assets/images/captain_logo.png", height: 32),
                              const SizedBox(width: 8),
                              Text("CAPTAIN", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18)),
                            ],
                          ),
                          actions: [
                             IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () {}),
                             const SizedBox(width: 8),
                          ],
                        ),
                        body: PageView(
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          physics: isWide ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                          children: _pages ?? [],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // 🚀 PROFESSIONAL PRINT ASSISTANT OVERLAY (Glassmorphism & Anti-Overflow)
            Consumer<PrinterService>(
              builder: (context, service, child) {
                if (!service.isJobActive) return const SizedBox.shrink();
                
                return Stack(
                  children: [
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ColorFilter.mode(Colors.black.withOpacity(0.8), BlendMode.darken),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 320,
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildAssistantIcon(service.currentJobState),
                              const SizedBox(height: 28),
                              Text(
                                _getAssistantTitle(service.currentJobState),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                service.jobStatusMessage,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  color: service.currentJobState == JobState.error ? AppColors.error : AppColors.textSecondary, 
                                  fontSize: 14, 
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                              const SizedBox(height: 32),
                              if (service.currentJobState != JobState.error) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: LinearProgressIndicator(
                                    value: service.jobProgress,
                                    backgroundColor: AppColors.border,
                                    color: _getAssistantColor(service.currentJobState),
                                    minHeight: 10,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),
                              TextButton(
                                onPressed: () => service.resetJobState(),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textTertiary,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("DISMISS", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: isWide ? null : BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: AppColors.textTertiary,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11),
          elevation: 8,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "HOME"),
            BottomNavigationBarItem(icon: Icon(Icons.pending_actions_rounded), label: "DELIVERIES"),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: "HISTORY"),
            BottomNavigationBarItem(icon: Icon(Icons.insights_rounded), label: "INSIGHTS"),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: "WALLET"),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "PROFILE"),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantIcon(JobState state) {
    IconData icon;
    Color color = _getAssistantColor(state);
    
    switch (state) {
      case JobState.completed: icon = Icons.check_circle_rounded; break;
      case JobState.error: icon = Icons.error_outline_rounded; break;
      case JobState.printing: icon = Icons.print_rounded; break;
      case JobState.queued: icon = Icons.hourglass_top_rounded; break;
      default: icon = Icons.print_rounded;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.9, end: 1.1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutSine,
      builder: (context, scale, child) {
        // Only pulse when printing
        final double currentScale = state == JobState.printing ? scale : 1.0;
        return Transform.scale(
          scale: currentScale,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1 * (state == JobState.printing ? scale : 1.0)),
              shape: BoxShape.circle,
              boxShadow: state == JobState.printing ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 20 * scale,
                  spreadRadius: 5 * scale,
                )
              ] : [],
            ),
            child: Icon(icon, color: color, size: 48),
          ),
        );
      },
      onEnd: () {}, // Handled by builder if we use a looping tween, but standard builder doesn't loop easily without state
    );
  }


  String _getAssistantTitle(JobState state) {
    switch (state) {
      case JobState.completed: return "Print Job Completed";
      case JobState.error: return "Printer Interaction Error";
      case JobState.printing: return "Handing over to Machine...";
      case JobState.queued: return "Analyzing Document...";
      default: return "ThinkInk Print Assistant";
    }
  }

  Color _getAssistantColor(JobState state) {
    if (state == JobState.completed) return AppColors.success;
    if (state == JobState.error) return AppColors.error;
    return AppColors.primaryBlue;
  }
}
