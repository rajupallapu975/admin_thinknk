import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';

class WalletTab extends StatefulWidget {
  final User user;
  const WalletTab({super.key, required this.user});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final shopRef = _firestore.collection('shops').doc(widget.user.uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Earnings & Payouts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: shopRef.snapshots(),
        builder: (context, shopSnapshot) {
          if (shopSnapshot.hasError) return _buildError("Shop data error");
          if (shopSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final shopData = shopSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final balance = (shopData['walletBalance'] ?? 0.0).toDouble();
          final bwPages = shopData['totalBwPages'] ?? 0;
          final colorPages = shopData['totalColorPages'] ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(balance),
                const SizedBox(height: 20),
                Text("Printing Stats", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatCard("B/W Pages", "$bwPages", Icons.print_rounded, Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard("Color Pages", "$colorPages", Icons.color_lens_rounded, Colors.orange)),
                  ],
                ),
                const SizedBox(height: 24),
                Text("Recent Transactions", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                
                // Nesting transaction list stream
                StreamBuilder<QuerySnapshot>(
                  stream: shopRef.collection('transactions')
                      .orderBy('timestamp', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, txSnapshot) {
                    if (txSnapshot.hasError) return const Text("History error");
                    if (txSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                    }

                    final transactions = txSnapshot.data!.docs;

                    if (transactions.isEmpty) return _buildEmptyTransactions();

                    return Column(
                      children: transactions.map((doc) {
                        final tx = doc.data() as Map<String, dynamic>;
                        return _buildTransactionItem(tx);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(double balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, Color(0xFF0056B3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Text(
            "₹${balance.toStringAsFixed(2)}",
            style: GoogleFonts.inter(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              _buildActionBtn(Icons.account_balance_rounded, "Withdraw"),
              const SizedBox(width: 12),
              _buildActionBtn(Icons.insights_rounded, "Insights"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final amount = (tx['amount'] ?? 0.0).toDouble();
    final timestamp = (tx['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isCredit = tx['type'] != 'debit';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isCredit ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCredit ? Icons.add_rounded : Icons.remove_rounded, 
            color: isCredit ? AppColors.success : AppColors.error,
            size: 20,
          ),
        ),
        title: Text(tx['title'] ?? "Printing Order", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 15)),
        subtitle: Text(DateFormat('dd MMM, hh:mm a').format(timestamp), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        trailing: Text(
          "${isCredit ? '+' : '-'}₹$amount", 
          style: TextStyle(
            color: isCredit ? AppColors.success : AppColors.error, 
            fontWeight: FontWeight.w800, 
            fontSize: 16
          )
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      width: double.infinity,
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text("No transactions yet", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(child: Text(msg, style: const TextStyle(color: Colors.red)));
  }
}
