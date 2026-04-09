import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';
import '../../models/app_user.dart';

class InsightsTab extends StatelessWidget {
  final AppUser user;
  const InsightsTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Financial Insights", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('withdrawal_requests')
            .where('shopId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text("Ledger Error: Please ensure Firestore indices are synced.", textAlign: TextAlign.center, style: GoogleFonts.manrope(color: AppColors.error, fontWeight: FontWeight.bold)),
            ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          // 🛡️ High-Fidelity Client-Side Sorting (Bypasses Index Issues)
          final docs = snapshot.data?.docs ?? [];
          final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
          sortedDocs.sort((a, b) {
            final aTime = (a.get('requestedAt') as Timestamp?)?.toDate() ?? DateTime(1970);
            final bTime = (b.get('requestedAt') as Timestamp?)?.toDate() ?? DateTime(1970);
            return bTime.compareTo(aTime); // Latest first
          });
          
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryBanner(sortedDocs),
                const SizedBox(height: 32),
                
                Text("SETTLEMENT PROGRESS", style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textTertiary, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                
                if (sortedDocs.isEmpty) _buildEmptyState()
                else Column(
                  children: sortedDocs.map((doc) => _buildPhonePeStylePayoutCard(doc.data() as Map<String, dynamic>)).toList(),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryBanner(List<QueryDocumentSnapshot> docs) {
    final paidCount = docs.where((d) => d.get('status') == 'paid').length;
    final totalSettled = docs.where((d) => d.get('status') == 'paid').fold(0.0, (val, d) => val + (d.get('amount') ?? 0.0));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
                child: Text("$paidCount SETTLED", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text("Total Settled", style: GoogleFonts.manrope(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("₹${totalSettled.toStringAsFixed(0)}", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
        ],
      ),
    );
  }

  Widget _buildPhonePeStylePayoutCard(Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final amount = (data['amount'] ?? 0.0).toDouble();
    final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    // Status Logic
    bool isPending = status == 'pending';
    bool isProcessing = status == 'processing';
    bool isPaid = status == 'paid';
    bool isRejected = status == 'rejected';

    Color statusColor = isPaid ? Colors.green : (isRejected ? Colors.red : Colors.orange);
    String statusText = status.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text("Withdrawal Request", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary)),
                   Text(DateFormat('dd MMM, hh:mm a').format(requestedAt), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
                ],
              ),
              Text("₹${amount.toInt()}", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 24),
          
          // PhonePe Style Progress Timeline
          Row(
            children: [
              _buildTimelineStep("Requested", true, true, isPaid || isProcessing || isPending),
              _buildTimelineDivider(isPaid || isProcessing),
              _buildTimelineStep("Verified", isPaid || isProcessing, isPaid || isProcessing, isPaid || isProcessing),
              _buildTimelineDivider(isPaid),
              _buildTimelineStep("Success", isPaid, isPaid, isPaid, isLast: true, isError: isRejected),
            ],
          ),
          
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(isPaid ? Icons.check_circle_rounded : (isRejected ? Icons.cancel_rounded : Icons.info_rounded), size: 14, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  isPaid ? "Bank Settlement Successful" : (isRejected ? "Request Invalid / Rejected" : "Administrative Review Pending"),
                  style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: -0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String label, bool isActive, bool isDone, bool isNow, {bool isLast = false, bool isError = false}) {
    Color color = isError ? Colors.red : (isDone ? Colors.green : (isActive ? AppColors.primaryBlue : Colors.grey.shade300));
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: isDone ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(
              isError ? Icons.close : (isDone ? Icons.check : Icons.circle), 
              size: 12, 
              color: isDone ? Colors.white : color
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label, 
            style: GoogleFonts.manrope(
              fontSize: 10, 
              fontWeight: isNow ? FontWeight.w900 : FontWeight.bold, 
              color: isNow ? AppColors.textPrimary : AppColors.textTertiary
            )
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDivider(bool isActive) {
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive ? Colors.green : Colors.grey.shade200,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text("No prior settlements", style: GoogleFonts.manrope(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
