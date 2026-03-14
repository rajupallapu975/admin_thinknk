import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show File;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../../utils/web_helpers/web_download.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';

class ProfileTab extends StatelessWidget {
  final User user;
  final Map<String, dynamic>? shopData;
  final ScreenshotController screenshotController = ScreenshotController();

  ProfileTab({super.key, required this.user, this.shopData});

  Future<void> _downloadQR(BuildContext context) async {
    try {
      final Uint8List? imageBytes = await screenshotController.capture();
      if (imageBytes == null) return;

      if (kIsWeb) {
        downloadBytes(imageBytes, "shop_qr_${user.uid.substring(0, 5)}.png");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("QR Code downloaded!"), backgroundColor: Colors.green),
          );
        }
        return;
      }

      // Gal handles permissions and saving in a modern way
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gallery permission denied")),
          );
          return;
        }
      }

      await Gal.putImageBytes(imageBytes, name: "shop_qr_${user.uid.substring(0, 5)}");
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("QR Code saved to Gallery!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Save Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareQR(BuildContext context) async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        if (!context.mounted) return;
        if (kIsWeb) {
          await _downloadQR(context);
          return;
        }

        final directory = await getTemporaryDirectory();
        final imageFile = await File('${directory.path}/shop_qr.png').create();
        await imageFile.writeAsBytes(image);
        
        await Share.shareXFiles([XFile(imageFile.path)], text: 'Scan this to visit my shop on ThinkInk: ${shopData?['shopName']}');
      }
    } catch (e) {
      debugPrint("Error sharing QR: $e");
    }
  }

  void _showQRCode(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text("Shop QR Identity", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5)),
              Text("Contains your unique Shop ID", style: GoogleFonts.manrope(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 32),
              
              Screenshot(
                controller: screenshotController,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      QrImageView(
                        data: user.uid,
                        version: QrVersions.auto,
                        size: 220.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(shopData?['shopName'] ?? "ThinkInk Shop", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text("Unique ID: ${user.uid}", style: GoogleFonts.manrope(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadQR(context),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text("Save to Phone"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareQR(context),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text("Share"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("DONE", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shop Profile', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            onPressed: () => AuthService().signOut(),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null ? const Icon(Icons.person, size: 54, color: AppColors.primaryBlue) : null,
            ),
            const SizedBox(height: 16),
            Text(
              shopData?['shopName'] ?? 'Captain Shop',
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5),
            ),
            Text(user.email ?? '', style: GoogleFonts.manrope(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),
            
            ElevatedButton.icon(
              onPressed: () => _showQRCode(context),
              icon: const Icon(Icons.qr_code_rounded),
              label: const Text("VIEW SHOP QR IDENTITY", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
            
            const Divider(height: 60),
            
            _buildProfileItem(Icons.fingerprint, 'Unique Shop ID', user.uid),
            _buildProfileItem(Icons.phone, 'Mobile', shopData?['mobile'] ?? 'N/A'),
            _buildProfileItem(Icons.login, 'Opens', shopData?['openingTime'] ?? 'N/A'),
            _buildProfileItem(Icons.logout, 'Closes', shopData?['closingTime'] ?? 'N/A'),
            _buildProfileItem(Icons.pin_drop, 'Pincode', shopData?['pincode'] ?? 'N/A'),
            _buildProfileItem(Icons.location_on, 'Location', shopData?['address'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                  Text(sub, style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
