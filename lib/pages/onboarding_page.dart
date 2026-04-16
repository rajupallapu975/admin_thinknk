import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/auth_service.dart';
import '../auth_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show File;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../utils/web_helpers/web_download.dart';
import '../utils/app_colors.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  bool _isLoadingLocation = false;
  bool _isSubmitting = false;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void dispose() {
    _pageController.dispose();
    _shopNameController.dispose();
    _mobileController.dispose();
    _pincodeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
      );
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuart,
      );
    }
  }

  Future<void> _selectTime(BuildContext context, bool isOpening) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpening ? const TimeOfDay(hour: 9, minute: 0) : const TimeOfDay(hour: 21, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied, we cannot request permissions.';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (!kIsWeb) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _locationController.text = "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}";
            _pincodeController.text = place.postalCode ?? "";
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location detected! Please enter your shop address manually.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _submit() async {
    if (_shopNameController.text.isEmpty || _mobileController.text.isEmpty || _pincodeController.text.isEmpty || _locationController.text.isEmpty || _openingTime == null || _closingTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please ensure all details are filled correctly.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final rawMobile = _mobileController.text.trim();
      final formattedMobile = rawMobile.startsWith('+') ? rawMobile : '+91 $rawMobile';

      final details = {
        'shopName': _shopNameController.text.trim(),
        'openingTime': _openingTime!.format(context),
        'closingTime': _closingTime!.format(context),
        'mobile': formattedMobile,
        'pincode': _pincodeController.text.trim(),
        'address': _locationController.text.trim(),
        'email': AuthService().currentUser?.email,
        'activePrinters': 1,
        'isCurrentlyOpen': true,
        'pricePerBWPage': 2.0,
        'pricePerColorPage': 10.0,
      };

      await AuthService().saveShopDetails(details);
      
      if (mounted) {
        final user = AuthService().currentUser;
        if (user != null) {
          _showQRSuccessDialog(user.uid, details['shopName'] as String);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submit Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🧱 PREVENT ENGINE ASSERTION: Wait until physical size is ready (Web fix)
    if (View.of(context).physicalSize.width <= 0) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Progress Indicator
                LinearProgressIndicator(
                  value: _totalSteps > 0 ? (_currentStep + 1) / _totalSteps : 0,
                  backgroundColor: AppColors.border,
                  color: AppColors.primaryBlue,
                  minHeight: 6,
                ),
                
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (idx) => setState(() => _currentStep = idx),
                    children: [
                      _buildIntroStep(),
                      _buildShopNameStep(),
                      _buildTimingsStep(),
                      _buildContactStep(),
                      _buildLocationStep(),
                    ],
                  ),
                ),
                
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContainer({required IconData icon, required String title, required String description, required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -1),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.manrope(fontSize: 16, color: AppColors.textSecondary, height: 1.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 48),
          child, // 🔥 Removed .animate() for Web compatibility fix
        ],
      ),
    );
  }

  Widget _buildIntroStep() {
    return _buildStepContainer(
      icon: Icons.rocket_launch_rounded,
      title: "Welcome to ThinkInk",
      description: "Let's set up your shop profile so customers can start finding you. This will take less than 2 minutes.",
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            _infoRow(Icons.check_circle_outline, "Customers will see your shop name"),
            const SizedBox(height: 12),
            _infoRow(Icons.check_circle_outline, "Your location helps nearby users find you"),
            const SizedBox(height: 12),
            _infoRow(Icons.check_circle_outline, "Business hours help users visit at the right time"),
          ],
        ),
      ),
    );
  }


  Widget _buildShopNameStep() {
    return _buildStepContainer(
      icon: Icons.storefront_rounded,
      title: "What's your shop's name?",
      description: "Choose a name that customers recognize easily. This is the face of your business on ThinkInk.",
      child: _buildTextField(
        _shopNameController,
        "Shop Name (e.g., Sri Krishna Xerox)",
        Icons.edit_note_rounded,
        autofocus: true,
      ),
    );
  }

  Widget _buildTimingsStep() {
    return _buildStepContainer(
      icon: Icons.access_time_filled_rounded,
      title: "Business Hours",
      description: "When do you start and end your services? This helps avoid customers arriving when you're closed.",
      child: Column(
        children: [
          _buildTimeSelector("Opening Time", _openingTime, true),
          const SizedBox(height: 16),
          _buildTimeSelector("Closing Time", _closingTime, false),
        ],
      ),
    );
  }

  Widget _buildContactStep() {
    return _buildStepContainer(
      icon: Icons.phone_callback_rounded,
      title: "Contact Details",
      description: "We'll use this mobile number for order notifications and for customers to reach you easily.",
      child: _buildTextField(
        _mobileController,
        "Mobile Number",
        Icons.phone_iphone_rounded,
        keyboardType: TextInputType.phone,
        autofocus: true,
        prefixText: "+91",
      ),
    );
  }

  Widget _buildLocationStep() {
    return _buildStepContainer(
      icon: Icons.location_on_rounded,
      title: "Shop Location",
      description: "This is crucial for local discoverability. We'll show your shop to users searching within your area.",
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _locationController,
                  "Full Address",
                  Icons.map_rounded,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              _buildLocationFetcher(),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _pincodeController,
            "Pincode",
            Icons.pin_drop_rounded,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
  Widget _buildTimeSelector(String label, TimeOfDay? time, bool isOpening) {
    return InkWell(
      onTap: () => _selectTime(context, isOpening),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: time != null ? AppColors.primaryBlue : AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Icon(isOpening ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded, color: time != null ? AppColors.primaryBlue : AppColors.textTertiary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                time?.format(context) ?? label,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: time != null ? AppColors.textPrimary : AppColors.textTertiary),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType? keyboardType, int maxLines = 1, bool autofocus = false, String? prefixText}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        autofocus: autofocus,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefixText != null ? '$prefixText ' : null,
          prefixStyle: prefixText != null ? GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary) : null,
          hintStyle: GoogleFonts.manrope(color: AppColors.textTertiary, fontWeight: FontWeight.w500),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(icon, color: AppColors.primaryBlue),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildLocationFetcher() {
    return InkWell(
      onTap: _isLoadingLocation ? null : _getCurrentLocation,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.softShadow,
        ),
        child: _isLoadingLocation 
          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          : const Icon(Icons.my_location_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: TextButton(
                onPressed: _prevStep,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text("BACK", style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.textTertiary, letterSpacing: 1)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_currentStep == _totalSteps - 1 ? "FINISH SETUP" : "CONTINUE", style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryBlue),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ],
    );
  }

  void _showQRSuccessDialog(String shopId, String shopName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  "Registration Successful!",
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Here is your unique Shop QR Identity.\nCustomers can scan this to find your shop.",
                  style: GoogleFonts.manrope(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        QrImageView(
                          data: 'thinkink-shop:$shopId',
                          version: QrVersions.auto,
                          size: 180.0,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(shopName, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadQR(shopId),
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: const Text("Save"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _shareQR(shopName),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text("Share"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthWrapper()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text("CONTINUE TO DASHBOARD", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadQR(String shopId) async {
    try {
      final Uint8List? imageBytes = await _screenshotController.capture();
      if (imageBytes == null) return;

      if (kIsWeb) {
        downloadBytes(imageBytes, "shop_qr_${shopId.substring(0, 5)}.png");
        return;
      }

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) return;
      }

      await Gal.putImageBytes(imageBytes, name: "shop_qr_${shopId.substring(0, 5)}");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QR Code saved to Gallery!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Save Error: $e");
    }
  }

  Future<void> _shareQR(String shopName) async {
    try {
      final image = await _screenshotController.capture();
      if (image != null) {
        if (kIsWeb) {
          _downloadQR("share");
          return;
        }

        final directory = await getTemporaryDirectory();
        final imageFile = await File('${directory.path}/shop_qr.png').create();
        await imageFile.writeAsBytes(image);
        
        await Share.shareXFiles([XFile(imageFile.path)], text: 'Scan this to find my shop "$shopName" on ThinkInk!');
      }
    } catch (e) {
      debugPrint("Error sharing QR: $e");
    }
  }
}
