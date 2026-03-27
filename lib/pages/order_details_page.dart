import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../services/printer_service.dart';
import '../utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsPage extends StatefulWidget {
  final OrderModel order;
  final String shopId;

  const OrderDetailsPage({super.key, required this.order, required this.shopId});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {

  Future<void> _handlePrint() async {
    final printerService = Provider.of<PrinterService>(context, listen: false);
    try {
      await printerService.handleDirectPrint(widget.order, widget.shopId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Order Details", style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.order.orderStatus == 'completed' ? Colors.grey.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.order.orderStatus.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: widget.order.orderStatus == 'completed' ? Colors.grey : AppColors.error,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.order.fileName,
              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -1),
            ),
            const SizedBox(height: 8),
            Text(
              "TICKET ID: ${widget.order.orderCode}",
              style: GoogleFonts.manrope(fontSize: 14, color: AppColors.textTertiary, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            
            const SizedBox(height: 32),
            Text("UPLOADED DOCUMENTS", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            ...List.generate(widget.order.fileUrls.length, (index) {
              final url = widget.order.fileUrls[index];
              final name = widget.order.fileNames.length > index ? widget.order.fileNames[index] : widget.order.fileName;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: AppColors.softShadow,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                        child: Icon(name.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded, size: 24, color: name.toLowerCase().endsWith('.pdf') ? AppColors.error : AppColors.primaryBlue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                            Text("A4 • ${name.split('.').last.toUpperCase()} • ${widget.order.getPageCount(index)} PAGES", style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication), icon: const Icon(Icons.download_rounded, color: AppColors.primaryBlue)),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 32),
            _buildConfigRow(Icons.palette_outlined, "Print Type", widget.order.colorPages > 0 ? "Color" : "Black & White"),
            _buildConfigRow(Icons.landscape_rounded, "Orientation", widget.order.orientation.toUpperCase()),
            _buildConfigRow(Icons.filter_none_rounded, "Copies", "${widget.order.copies} Set(s)"),
            _buildConfigRow(Icons.chrome_reader_mode_outlined, "Sides", widget.order.isDuplex ? "Double-Sided" : "Single-Sided"),
            _buildConfigRow(Icons.payments_outlined, "Service Fee", "₹${widget.order.amount.toStringAsFixed(2)}", isLast: true),

            const SizedBox(height: 40),
            Text("CUSTOMER INFO", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1), child: const Icon(Icons.person, color: AppColors.primaryBlue)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.order.customerName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16), overflow: TextOverflow.ellipsis),
                        if (widget.order.customerPhone != null)
                          Text(widget.order.customerPhone!, style: GoogleFonts.manrope(fontSize: 14, color: AppColors.primaryBlue, fontWeight: FontWeight.w800)),
                        Text("Sent at ${DateFormat('hh:mm a').format(widget.order.timestamp)}", style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        color: AppColors.surface,
        child: ElevatedButton.icon(
          onPressed: _handlePrint,
          icon: const Icon(Icons.print_rounded),
          label: const Text("START PRINTING", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 64), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
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
            Expanded(child: Text(label, style: GoogleFonts.manrope(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
            Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ],
        ),
        if (!isLast) Divider(color: AppColors.border.withValues(alpha: 0.5), height: 32),
      ],
    );
  }
}
