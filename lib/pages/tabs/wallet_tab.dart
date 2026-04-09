import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';

class WalletTab extends StatefulWidget {
  final AppUser user;
  const WalletTab({super.key, required this.user});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showWithdrawalForm(double currentBalance, Map<String, dynamic> shopData) {
    if (currentBalance < 10) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Min withdrawal is ₹10! 🪙"), backgroundColor: Colors.orange));
       return;
    }

    // Use floor to ensure default suggested amount never exceeds balance
    final String defaultAmount = currentBalance.floor().toString();
    
    final TextEditingController bankNameController = TextEditingController();
    final TextEditingController ifscController = TextEditingController();
    final TextEditingController accountController = TextEditingController();
    final TextEditingController mobileController = TextEditingController(); 
    final TextEditingController amountController = TextEditingController(text: defaultAmount);
    
    bool hasSavedAccount = shopData['bankName'] != null && shopData['accountNumber'] != null;
    bool useSavedAccount = hasSavedAccount;

    if (hasSavedAccount) {
      bankNameController.text = shopData['bankName'] ?? '';
      ifscController.text = shopData['ifscCode'] ?? '';
      accountController.text = shopData['accountNumber'] ?? '';
      mobileController.text = shopData['bankMobile'] ?? '';
    }

    final DocumentReference shopRef = _firestore.collection('shops').doc(widget.user.uid);
    
    // 🔥 Improved Validation States
    String? amountError;
    String? ifscError;
    String? accountError;
    String? mobileError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          
          bool isFormValid() {
            if (double.tryParse(amountController.text) == null || (double.tryParse(amountController.text) ?? 0) < 10 || (double.tryParse(amountController.text) ?? 0) > currentBalance) return false;
            if (amountError != null) return false;
            
            if (useSavedAccount) return true;
            
            // 🛡️ Relaxed Validation: Merchants must ensure accuracy manually
            if (bankNameController.text.trim().isEmpty) return false;
            if (ifscController.text.trim().isEmpty) return false;
            if (accountController.text.trim().isEmpty) return false;
            if (mobileController.text.trim().length < 10) return false;
            
            return true;
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Text("Request Payout", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Min: ₹10", style: GoogleFonts.manrope(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 13)),
                      Text("Available: ₹${currentBalance.toStringAsFixed(2)}", style: GoogleFonts.manrope(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // 🏁 Professional Warning Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.2))),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text("Ensure all bank details are 100% correct to avoid settlement delays.", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (hasSavedAccount) ...[
                    Text("SETTLEMENT DESTINATION", style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() {
                              useSavedAccount = true;
                              bankNameController.text = shopData['bankName'] ?? '';
                              ifscController.text = shopData['ifscCode'] ?? '';
                              accountController.text = shopData['accountNumber'] ?? '';
                              mobileController.text = shopData['bankMobile'] ?? '';
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: useSavedAccount ? AppColors.primaryBlue.withValues(alpha: 0.05) : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: useSavedAccount ? AppColors.primaryBlue : AppColors.border, width: 2),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.verified_rounded, color: useSavedAccount ? AppColors.primaryBlue : Colors.grey, size: 24),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(shopData['bankName'] ?? "Saved Bank", style: TextStyle(fontWeight: FontWeight.w900, color: useSavedAccount ? AppColors.textPrimary : Colors.grey, fontSize: 14)),
                                      Text("A/C: ****${accountController.text.length > 4 ? accountController.text.substring(accountController.text.length - 4) : accountController.text}", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() {
                              useSavedAccount = false;
                              bankNameController.clear();
                              ifscController.clear();
                              accountController.clear();
                              mobileController.clear();
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: !useSavedAccount ? AppColors.primaryBlue.withValues(alpha: 0.05) : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: !useSavedAccount ? AppColors.primaryBlue : AppColors.border, width: 2),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline_rounded, color: !useSavedAccount ? AppColors.primaryBlue : Colors.grey, size: 24),
                                  const SizedBox(width: 12),
                                  const Text("New Bank", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (!useSavedAccount) ...[
                    _buildTextField(bankNameController, "Bank Name (e.g. HDFC)", Icons.account_balance_rounded),
                    const SizedBox(height: 16),
                    _buildTextField(ifscController, "IFSC Code", Icons.qr_code_rounded, errorText: ifscError, onChanged: (v) {
                      setModalState(() => ifscError = (v.trim().isEmpty) ? "Required" : null);
                    }),
                    const SizedBox(height: 16),
                    _buildTextField(accountController, "Account Number", Icons.numbers_rounded, isNumber: true, errorText: accountError, onChanged: (v) {
                      setModalState(() => accountError = (v.trim().isEmpty) ? "Required" : null);
                    }),
                    const SizedBox(height: 16),
                    _buildTextField(mobileController, "Mobile linked to Bank", Icons.phone_android_rounded, isNumber: true, errorText: mobileError, onChanged: (v) {
                      setModalState(() => mobileError = (v.length == 10) ? null : "Enter 10-digit mobile");
                    }),
                    const SizedBox(height: 16),
                  ],
                  
                  _buildTextField(amountController, "Withdraw Amount (₹)", Icons.payments_rounded, isNumber: true, errorText: amountError, onChanged: (v) {
                    final amt = double.tryParse(v) ?? 0;
                    setModalState(() => amountError = (amt >= 10 && amt <= currentBalance) ? null : "Must be ₹10 - ₹${currentBalance.toStringAsFixed(0)}");
                  }),
                  
                  const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: !isFormValid() ? null : () async {
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    try {
                      await _firestore.runTransaction((transaction) async {
                        final shopDoc = await transaction.get(shopRef);
                        final liveBalance = (shopDoc.data() as Map<String, dynamic>?)?['walletBalance'] ?? 0.0;
                        if (liveBalance < amount) throw "Insufficient balance";

                        transaction.update(shopRef, {
                          'walletBalance': (liveBalance - amount).toDouble(),
                          'bankName': bankNameController.text.trim().toUpperCase(),
                          'ifscCode': ifscController.text.trim().toUpperCase(),
                          'accountNumber': accountController.text.trim(),
                          'bankMobile': mobileController.text.trim(),
                        });

                        final requestRef = _firestore.collection('withdrawal_requests').doc();
                        transaction.set(requestRef, {
                          'requestId': requestRef.id,
                          'shopId': widget.user.uid,
                          'shopName': shopData['shopName'] ?? 'Shop',
                          'shopMobile': shopData['mobile'] ?? 'N/A',
                          'bankName': bankNameController.text.trim().toUpperCase(),
                          'ifscCode': ifscController.text.trim().toUpperCase(),
                          'accountNumber': accountController.text.trim(),
                          'bankMobile': mobileController.text.trim(),
                          'amount': amount,
                          'status': 'pending',
                          'requestedAt': FieldValue.serverTimestamp(),
                        });

                        final transRef = shopRef.collection('transactions').doc();
                        transaction.set(transRef, {
                          'amount': amount,
                          'title': 'Payout Request: Pending',
                          'timestamp': FieldValue.serverTimestamp(),
                          'type': 'debit',
                          'status': 'pending',
                          'requestId': requestRef.id,
                        });
                      });

                      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Success!"), backgroundColor: AppColors.success)); }
                    } catch (e) {
                       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 64),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text("SUBMIT WITHDRAWAL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, String? errorText, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: errorText != null ? AppColors.error : AppColors.border, width: errorText != null ? 1.5 : 1)),
          child: TextField(
            controller: ctrl, onChanged: onChanged,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
            decoration: InputDecoration(
              icon: Icon(icon, color: errorText != null ? AppColors.error : AppColors.primaryBlue, size: 20), 
              labelText: label, 
              labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
              border: InputBorder.none
            ),
          ),
        ),
        if (errorText != null) Padding(padding: const EdgeInsets.only(left: 12, top: 4), child: Text(errorText, style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopRef = _firestore.collection('shops').doc(widget.user.uid);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("Earnings & Payouts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22))),
      body: StreamBuilder<DocumentSnapshot>(
        stream: shopRef.snapshots(),
        builder: (context, shopSnapshot) {
          if (!shopSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final shopData = shopSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final balance = (shopData['walletBalance'] ?? 0.0).toDouble();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(balance, shopData),
                const SizedBox(height: 32),
                Text("Printing Stats", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatCard("B/W Pages", "${shopData['totalBwPages'] ?? 0}", Icons.print_rounded, Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard("Color Pages", "${shopData['totalColorPages'] ?? 0}", Icons.color_lens_rounded, Colors.orange)),
                  ],
                ),
                const SizedBox(height: 48),
                Center(
                  child: Text(
                    "Switch to INSIGHTS tab for full history", 
                    style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textTertiary)
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(double balance, Map<String, dynamic> shopData) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primaryBlue, Color(0xFF0056B3)], begin: Alignment.topLeft, end: Alignment.bottomRight), 
        borderRadius: BorderRadius.circular(24), 
        boxShadow: AppColors.mediumShadow
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text("₹${balance.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900)),
          const SizedBox(height: 28),
          InkWell(
            onTap: () => _showWithdrawalForm(balance, shopData),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16), 
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)), 
              child: const Center(child: Text("Withdraw Funds", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)))
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Icon(icon, color: color, size: 24), 
          const SizedBox(height: 16), 
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)), 
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))
        ]
      )
    );
  }
}
