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
    bool isWide = MediaQuery.of(context).size.width > 900;
    
    if (currentBalance < 10) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Min withdrawal is ₹10! 🪙"), backgroundColor: Colors.orange));
       return;
    }

    // Use floor to ensure default suggested amount never exceeds balance
    final String defaultAmount = currentBalance.floor().toString();
    
    final TextEditingController bankNameController = TextEditingController();
    final TextEditingController holderNameController = TextEditingController(); 
    final TextEditingController ifscController = TextEditingController();
    final TextEditingController accountController = TextEditingController();
    final TextEditingController mobileController = TextEditingController(); 
    final TextEditingController amountController = TextEditingController(text: defaultAmount);
    
    // 🔥 Free Access: Always allow manual entry/edit, pre-fill with saved details
    bankNameController.text = shopData['bankName'] ?? '';
    holderNameController.text = shopData['holderName'] ?? '';
    ifscController.text = shopData['ifscCode'] ?? '';
    accountController.text = shopData['accountNumber'] ?? '';
    mobileController.text = shopData['bankMobile'] ?? '';

    final DocumentReference shopRef = _firestore.collection('shops').doc(widget.user.uid);
    
    // 🔥 Improved Validation States
    String? amountError;
    String? ifscError;
    String? accountError;
    String? mobileError;
    
    bool _isExpanded = false; 
    bool _isNewBank = false;  

    if (isWide) {
      showDialog(
        context: context,
        builder: (context) => _buildWithdrawalModal(currentBalance, shopData, bankNameController, holderNameController, ifscController, accountController, mobileController, amountController, shopRef, amountError, ifscError, accountError, mobileError, _isExpanded, _isNewBank),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildWithdrawalModal(currentBalance, shopData, bankNameController, holderNameController, ifscController, accountController, mobileController, amountController, shopRef, amountError, ifscError, accountError, mobileError, _isExpanded, _isNewBank),
      );
    }
  }

  Widget _buildWithdrawalModal(
    double currentBalance, Map<String, dynamic> shopData, 
    TextEditingController bankNameController, TextEditingController holderNameController,
    TextEditingController ifscController, TextEditingController accountController,
    TextEditingController mobileController, TextEditingController amountController,
    DocumentReference shopRef, String? amountError, String? ifscError, String? accountError, String? mobileError,
    bool initialExpanded, bool initialNewBank
  ) {
    bool isWide = MediaQuery.of(context).size.width > 900;
    bool _isExpanded = initialExpanded;
    bool _isNewBank = initialNewBank;
    bool _isLoading = false; 
    return StatefulBuilder(
      builder: (context, setModalState) {
        bool isFormValid() {
          if (double.tryParse(amountController.text) == null || (double.tryParse(amountController.text) ?? 0) < 10 || (double.tryParse(amountController.text) ?? 0) > currentBalance) return false;
          if (amountError != null) return false;
          if (!_isExpanded) return false;
          
          if (bankNameController.text.trim().isEmpty) return false;
          if (holderNameController.text.trim().isEmpty) return false;
          if (ifscController.text.trim().isEmpty) return false;
          if (accountController.text.trim().isEmpty) return false;
          if (mobileController.text.trim().length < 10) return false;
          
          return true;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(maxWidth: isWide ? 500 : double.infinity),
                  margin: isWide ? const EdgeInsets.all(32) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isWide ? 32 : 0).copyWith(
                      topLeft: const Radius.circular(32),
                      topRight: const Radius.circular(32),
                    ),
                    boxShadow: isWide ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 10))] : null,
                  ),
                padding: EdgeInsets.only(
                  left: 28, right: 28, top: 28,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 28,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isWide) Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Request Payout", style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                          if (isWide) IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Min: ₹10", style: GoogleFonts.manrope(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 13)),
                          Text("Available: ₹${currentBalance.toStringAsFixed(2)}", style: GoogleFonts.manrope(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      _buildTextField(amountController, "Withdraw Amount (₹)", Icons.payments_rounded, isNumber: true, errorText: amountError, onChanged: (v) {
                        final amt = double.tryParse(v) ?? 0;
                        setModalState(() => amountError = (amt >= 10 && amt <= currentBalance) ? null : "Must be ₹10 - ₹${currentBalance.toStringAsFixed(0)}");
                      }),

                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withOpacity(0.2))),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                            SizedBox(width: 12),
                            Expanded(child: Text("Ensure details are 100% correct to avoid processing delays.", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 🏦 Selection Bars
                      if (shopData['bankName'] != null) ...[
                        _buildSelectionBar(
                          title: "USE REGISTERED ACCOUNT",
                          subtitle: "${shopData['bankName']} (****${shopData['accountNumber']?.toString().substring((shopData['accountNumber']?.toString().length ?? 4) - 4)})",
                          extra: shopData['holderName'],
                          icon: Icons.account_balance_rounded,
                          isSelected: _isExpanded && !_isNewBank,
                          onTap: () => setModalState(() {
                             if (_isExpanded && !_isNewBank) {
                               _isExpanded = false;
                             } else {
                               _isExpanded = true;
                               _isNewBank = false;
                               bankNameController.text = shopData['bankName'] ?? '';
                               holderNameController.text = shopData['holderName'] ?? '';
                               ifscController.text = shopData['ifscCode'] ?? '';
                               accountController.text = shopData['accountNumber'] ?? '';
                               mobileController.text = shopData['bankMobile'] ?? '';
                             }
                          }),
                        ),
                        const SizedBox(height: 12),
                      ],

                      _buildSelectionBar(
                        title: "USE NEW BANK ACCOUNT",
                        icon: Icons.add_circle_outline_rounded,
                        isSelected: _isExpanded && _isNewBank,
                        onTap: () => setModalState(() {
                          if (_isExpanded && _isNewBank) {
                            _isExpanded = false;
                          } else {
                            _isExpanded = true;
                            _isNewBank = true;
                            bankNameController.clear();
                            holderNameController.clear();
                            ifscController.clear();
                            accountController.clear();
                            mobileController.clear();
                          }
                        }),
                      ),

                      if (_isExpanded) ...[
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_isNewBank ? "ENTER NEW BANK" : "REGISTERED DETAILS", style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 1.5)),
                            if (!_isNewBank) Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textTertiary),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(bankNameController, "Bank Name (e.g. HDFC)", Icons.account_balance_rounded, readOnly: !_isNewBank),
                        const SizedBox(height: 16),
                        _buildTextField(holderNameController, "Account Holder Name", Icons.person_rounded, readOnly: !_isNewBank),
                        const SizedBox(height: 16),
                        _buildTextField(ifscController, "IFSC Code", Icons.qr_code_rounded, errorText: ifscError, readOnly: !_isNewBank, onChanged: (v) {
                          setModalState(() => ifscError = (v.trim().isEmpty) ? "Required" : null);
                        }),
                        const SizedBox(height: 16),
                        _buildTextField(accountController, "Account Number", Icons.numbers_rounded, isNumber: true, errorText: accountError, readOnly: !_isNewBank, onChanged: (v) {
                          setModalState(() => accountError = (v.trim().isEmpty) ? "Required" : null);
                        }),
                        const SizedBox(height: 16),
                        _buildTextField(mobileController, "Mobile linked to Bank", Icons.phone_android_rounded, isNumber: true, errorText: mobileError, readOnly: !_isNewBank, onChanged: (v) {
                          setModalState(() => mobileError = (v.length == 10) ? null : "Enter 10-digit mobile");
                        }),
                        if (_isNewBank) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                            child: CheckboxListTile(
                              value: shopData['saveDetails'] ?? true, // Local state or temporary bool needed
                              onChanged: (v) => setModalState(() => shopData['saveDetails'] = v),
                              title: const Text("Save these details for future use?", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              activeColor: AppColors.primaryBlue,
                              dense: true,
                            ),
                          ),
                        ],
                      ],
                      
                      const SizedBox(height: 32),
                      
                      if (_isExpanded && amountController.text.isNotEmpty && amountError == null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               Text("TOTAL PAYOUT", style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textTertiary)),
                               Text("₹${amountController.text}", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primaryBlue)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      ElevatedButton(
                        onPressed: (_isLoading || !isFormValid()) ? null : () async {
                           final bool? confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                              title: Text("Confirm Payout", style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Amount: ₹${amountController.text}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryBlue)),
                                  const SizedBox(height: 20),
                                  _confirmRow(Icons.account_balance_rounded, bankNameController.text),
                                  _confirmRow(Icons.person_rounded, holderNameController.text),
                                  _confirmRow(Icons.numbers_rounded, accountController.text),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  child: const Text("PROCEED"),
                                ),
                              ],
                            ),
                          );

                          if (confirmed != true) return;

                          setModalState(() => _isLoading = true);
                          final amount = double.tryParse(amountController.text) ?? 0.0;
                          try {
                            await shopRef.firestore.runTransaction((transaction) async {
                              final shopDoc = await transaction.get(shopRef);
                              final liveBalance = (shopDoc.data() as Map<String, dynamic>?)?['walletBalance'] ?? 0.0;
                              if (liveBalance < amount) throw "Insufficient balance";

                              final saveDetails = shopData['saveDetails'] ?? true;
                              if (saveDetails) {
                                transaction.update(shopRef, {
                                  'walletBalance': (liveBalance - amount).toDouble(),
                                  'bankName': bankNameController.text.trim().toUpperCase(),
                                  'holderName': holderNameController.text.trim().toUpperCase(),
                                  'ifscCode': ifscController.text.trim().toUpperCase(),
                                  'accountNumber': accountController.text.trim(),
                                  'bankMobile': mobileController.text.trim(),
                                });
                              } else {
                                transaction.update(shopRef, {
                                  'walletBalance': (liveBalance - amount).toDouble(),
                                });
                              }

                              final requestRef = FirebaseFirestore.instance.collection('withdrawal_requests').doc();
                              transaction.set(requestRef, {
                                'requestId': requestRef.id,
                                'shopId': widget.user.uid,
                                'shopName': shopData['shopName'] ?? 'Shop',
                                'shopMobile': shopData['mobile'] ?? 'N/A',
                                'bankName': bankNameController.text.trim().toUpperCase(),
                                'holderName': holderNameController.text.trim().toUpperCase(),
                                'ifscCode': ifscController.text.trim().toUpperCase(),
                                'accountNumber': accountController.text.trim(),
                                'bankMobile': mobileController.text.trim(),
                                'amount': amount,
                                'status': 'pending',
                                'requestedAt': FieldValue.serverTimestamp(),
                                'notified': false, // Ensure backend sees it
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
                            if (context.mounted) { 
                              Navigator.pop(context); 
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payout Request Submitted!"), backgroundColor: AppColors.success)); 
                            }
                          } catch (e) {
                             setModalState(() => _isLoading = false);
                             if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          disabledBackgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 64),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text("SUBMIT Payout", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }

  Widget _buildSelectionBar({required String title, String? subtitle, String? extra, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primaryBlue : AppColors.border, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryBlue : AppColors.textTertiary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w900, color: isSelected ? AppColors.textPrimary : AppColors.textTertiary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                  if (extra != null) ...[
                    Text("Name: $extra", style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            Icon(Icons.check_circle_rounded, color: isSelected ? AppColors.primaryBlue : Colors.transparent, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, String? errorText, bool readOnly = false, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: readOnly ? Colors.grey.shade50 : AppColors.background, 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: errorText != null ? AppColors.error : (readOnly ? Colors.grey.shade200 : AppColors.border), width: errorText != null ? 1.5 : 1)
          ),
          child: TextField(
            controller: ctrl, onChanged: onChanged,
            readOnly: readOnly,
            style: TextStyle(color: readOnly ? AppColors.textSecondary : AppColors.textPrimary, fontWeight: readOnly ? FontWeight.w600 : FontWeight.normal),
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
            decoration: InputDecoration(
              icon: Icon(icon, color: errorText != null ? AppColors.error : (readOnly ? Colors.grey : AppColors.primaryBlue), size: 20), 
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

  Widget _confirmRow(IconData icon, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Expanded(child: Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
        ],
      ),
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
    bool isWide = MediaQuery.of(context).size.width > 900;
    return Container(
      width: double.infinity, padding: EdgeInsets.all(isWide ? 40 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, Color(0xFF1E3A8A), Color(0xFF0056B3)], 
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight
        ), 
        borderRadius: BorderRadius.circular(32), 
        boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 15))]
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
                  const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text("₹${balance.toStringAsFixed(2)}", style: GoogleFonts.inter(color: Colors.white, fontSize: isWide ? 48 : 38, fontWeight: FontWeight.w900, letterSpacing: -1)),
                ],
              ),
              if (isWide) const Icon(Icons.account_balance_wallet_rounded, color: Colors.white30, size: 80),
            ],
          ),
          const SizedBox(height: 40),
          Align(
            alignment: isWide ? Alignment.centerLeft : Alignment.center,
            child: InkWell(
              onTap: () => _showWithdrawalForm(balance, shopData),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 48), 
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20), 
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
                ), 
                child: Text("Withdraw Funds", style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w900, fontSize: 15))
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24), 
      decoration: BoxDecoration(
        color: AppColors.surface, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ), 
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)), 
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5))
              ]
            ),
          ),
        ],
      )
    );
  }
}
