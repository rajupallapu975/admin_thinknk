import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../services/printer_service.dart';
import '../utils/app_colors.dart';
import 'printer_connecting_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'image_viewer_page.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OrderDetailsPage extends StatefulWidget {
  final OrderModel order;
  final String shopId;

  const OrderDetailsPage({super.key, required this.order, required this.shopId});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  bool _isPrinting = false;

  Future<void> _launchViewer() async {
    if (widget.order.fileUrl == null) return;
    final url = Uri.parse(widget.order.fileUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open document."), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildFileThumbnail() {
    final isImage = widget.order.isImageFile && widget.order.fileUrl != null;
    
    if (isImage) {
      return Image.network(
        widget.order.fileUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image, color: AppColors.primaryBlue),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
        },
      );
    }
    
    return Icon(
      widget.order.fileName.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
      color: widget.order.fileName.toLowerCase().endsWith('.pdf') ? AppColors.error : AppColors.primaryBlue,
    );
  }

  Future<void> _handlePrint() async {
    final printerService = Provider.of<PrinterService>(context, listen: false);

    if (!printerService.isConnected) {
      // Save for resumption and navigate
      printerService.handleDirectPrint(widget.order, widget.shopId);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrinterConnectingPage()),
      );
      return;
    }

    setState(() => _isPrinting = true);
    
    try {
      await printerService.handleDirectPrint(widget.order, widget.shopId);
      
      if (mounted) {
        Navigator.pop(context); // Return after completion
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Processing Print. Check Pending Tab."), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Order Context", style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "ACTIVE ORDER",
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.success, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.order.fileName,
              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -1),
            ),
            const SizedBox(height: 8),
            Text(
              "ORDER ID: ${widget.order.orderCode}",
              style: GoogleFonts.manrope(fontSize: 14, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
            ),
            
            const SizedBox(height: 32),
            
            // File Preview Section
            Text("UPLOADED FILE", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: InkWell(
                onTap: () {
                  if (widget.order.fileUrl == null || widget.order.fileUrl!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error: No file URL found for this order."), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  
                  final isImage = widget.order.isImageFile;

                  if (isImage) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImageViewerPage(
                          imageUrl: widget.order.fileUrl!,
                          fileName: widget.order.fileName,
                        ),
                      ),
                    );
                  } else {
                    _launchViewer();
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildFileThumbnail(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.order.fileName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15), overflow: TextOverflow.ellipsis),
                            Text(
                              widget.order.fileName.toLowerCase().endsWith('.pdf') ? "PDF Document" : "Image File", 
                              style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textSecondary)
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "VIEW",
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
            
            // Print Configuration
            Text("PRINT CONFIGURATION", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            _buildConfigRow(Icons.description_outlined, "Total Pages", "${widget.order.totalPages} Pages"),
            _buildConfigRow(Icons.color_lens_outlined, "Color Mode", widget.order.colorPages > 0 ? "Color" : "Black & White"),
            _buildConfigRow(Icons.copy_all_outlined, "Side Mode", widget.order.isDuplex ? "Double Sided" : "Single Sided"),
            _buildConfigRow(Icons.payments_outlined, "Earnings", "₹${widget.order.amount.toStringAsFixed(2)}", isLast: true),

            const SizedBox(height: 40),
            
            // Customer Info
            Text("CUSTOMER INFO", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.order.customerName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16), overflow: TextOverflow.ellipsis),
                        Text("Sent at ${DateFormat('hh:mm a').format(widget.order.timestamp)}", style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 100), // Space for button
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isPrinting ? null : _handlePrint,
          icon: _isPrinting 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.print_rounded),
          label: Text(
            _isPrinting ? "PRINTING..." : "START PRINTING",
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 64),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildConfigRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label, 
                style: GoogleFonts.manrope(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.border.withValues(alpha: 0.5)),
          ),
      ],
    );
  }
}
