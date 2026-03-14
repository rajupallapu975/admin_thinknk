import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/printer_service.dart';
import '../utils/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:printing/printing.dart';

class PrinterConnectingPage extends StatefulWidget {
  const PrinterConnectingPage({super.key});

  @override
  State<PrinterConnectingPage> createState() => _PrinterConnectingPageState();
}

class _PrinterConnectingPageState extends State<PrinterConnectingPage> {
  void _connect(Printer printer) async {
    final printerService = Provider.of<PrinterService>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: AppColors.primaryBlue),
            const SizedBox(height: 24),
            Text(
              "Connecting to ${printer.name}...",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              "Establishing hardware handshake...",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );

    final user = FirebaseAuth.instance.currentUser;
    await printerService.connectPrinter(printer, user?.uid ?? "");
    
    if (mounted) {
      Navigator.pop(context); // Close dialog
      Navigator.pop(context); // Return to previous screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connected to ${printer.name}"),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerService = Provider.of<PrinterService>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Printers", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.black)),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              "Make sure that the printer and your device are connected to the same network, or that the printer has Wi-Fi Direct turned on. Still can't discover the printer? Try system settings.",
              style: GoogleFonts.manrope(fontSize: 14, color: Colors.black54, height: 1.5),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Divider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Available devices",
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black26),
                ),
              ],
            ),
          ),
          Expanded(
            child: kIsWeb 
                ? _buildWebWarning()
                : FutureBuilder<List<Printer>>(
                future: Printing.listPrinters(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink(); // Loader is in the header row
                  }

                  final systemPrinters = snapshot.data ?? [];
                  final seenNames = <String>{};
                  final available = systemPrinters.where((p) {
                    if (seenNames.contains(p.name) || printerService.connectedPrinters.contains(p.name)) {
                      return false;
                    }
                    seenNames.add(p.name);
                    return true;
                  }).toList();

                  if (available.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    itemCount: available.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(height: 1),
                    ),
                    itemBuilder: (context, index) {
                      final p = available[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFF0F0F0),
                          child: Icon(Icons.print_outlined, color: Colors.black54, size: 20),
                        ),
                        title: Text(p.name, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.black)),
                        subtitle: Text("Ready to connect", style: GoogleFonts.manrope(fontSize: 12, color: Colors.black38)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                        onTap: () => _connect(p),
                      );
                    },
                  );
                },
              ),
          ),
          // Footer Settings Button
          Container(
            padding: const EdgeInsets.all(24),
            child: OutlinedButton(
              onPressed: () {
                if (defaultTargetPlatform == TargetPlatform.windows) {
                  launchUrl(Uri.parse('ms-settings:printers'));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please open your mobile Wi-Fi/Bluetooth settings.")),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                "OPEN SYSTEM SETTINGS",
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.black54, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebWarning() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.web_rounded, size: 48, color: Colors.black26),
            const SizedBox(height: 24),
            Text("Browser discovery limited", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(
              "For full automatic discovery, please use the mobile or desktop app.",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: Colors.black38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: Colors.black12),
          const SizedBox(height: 16),
          Text("No devices found", style: GoogleFonts.inter(color: Colors.black38, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
