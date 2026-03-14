import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class PendingTab extends StatefulWidget {
  final User user;
  const PendingTab({super.key, required this.user});

  @override
  State<PendingTab> createState() => _PendingTabState();
}

class _PendingTabState extends State<PendingTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _finalizeJob(OrderModel order) async {
    final shopRef = _firestore.collection('shops').doc(widget.user.uid);
    
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Update Order Status to 'completed'
        transaction.update(shopRef.collection('orders').doc(order.id), {'status': 'completed'});

        // 2. Fetch Shop Wallet
        final shopDoc = await transaction.get(shopRef);
        if (!shopDoc.exists) return;

        final currentBalance = (shopDoc.data()?['walletBalance'] ?? 0.0).toDouble();
        final currentBw = shopDoc.data()?['totalBwPages'] ?? 0;
        final currentColor = shopDoc.data()?['totalColorPages'] ?? 0;

        // 3. Update Wallet & Stats
        transaction.update(shopRef, {
          'walletBalance': currentBalance + order.amount,
          'totalBwPages': currentBw + order.bwPages,
          'totalColorPages': currentColor + order.colorPages,
        });

        // 4. Record Transaction
        final historyRef = shopRef.collection('transactions').doc();
        transaction.set(historyRef, {
          'amount': order.amount,
          'title': "Print Done: ${order.fileName}",
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'credit',
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Job Completed! Wallet updated."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Finalize Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Processing Prints", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.textPrimary, letterSpacing: -1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('shops')
            .doc(widget.user.uid)
            .collection('orders')
            .where('status', isEqualTo: 'printing')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final orders = snapshot.data!.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
          
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty_rounded, size: 80, color: AppColors.textTertiary.withValues(alpha: 0.2)),
                  const SizedBox(height: 24),
                  Text(
                    "No active printing jobs",
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text("Waiting for incoming Xerox orders...", style: GoogleFonts.manrope(color: AppColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) => _buildPendingCard(orders[index]),
          );
        },
      ),
    );
  }

  Widget _buildPendingCard(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
                  ),
                ),
                _printingBadge(),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "ORDER ID: ${order.orderCode}", 
                style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w900, fontSize: 10)
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Print Detected: ${order.printedAt != null ? DateFormat('hh:mm a').format(order.printedAt!) : 'Processing...'} ${order.lastPrinterUsed != null ? 'on ${order.lastPrinterUsed}' : ''}",
              style: GoogleFonts.manrope(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.isImageFile && order.fileUrl != null)
                  Container(
                    width: 70,
                    height: 70,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      order.fileUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 20, color: AppColors.textTertiary),
                    ),
                  ),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _symbolChip(order.bwPages > 0 ? Icons.contrast : null, order.bwPages > 0 ? "B/W" : ""),
                      _symbolChip(order.colorPages > 0 ? Icons.palette : null, order.colorPages > 0 ? "COLOR" : ""),
                      _symbolChip(order.isDuplex ? Icons.copy_all : Icons.description, order.isDuplex ? "2-SIDED" : "1-SIDE"),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 40, color: AppColors.greyLight),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text("Sent: ${DateFormat('hh:mm a').format(order.timestamp)}", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _finalizeJob(order),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text("MARK DONE", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _printingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 8),
          const Text("PRINTING", style: TextStyle(color: AppColors.primaryBlue, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _symbolChip(IconData? icon, String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
