import 'package:admin_thinkink/models/order_model.dart';
import 'package:admin_thinkink/utils/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/history_service.dart';
import '../../models/app_user.dart';

class HistoryTab extends StatefulWidget {
  final AppUser user;
  const HistoryTab({super.key, required this.user});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  // 🛡️ Data is managed entirely by HistoryService using local SharedPreferences.
  // No Firebase WRITE operations occur in this Tab.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Order History", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<HistoryService>(
        builder: (context, service, _) {
          final orders = service.history;

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.history_rounded, size: 80, color: AppColors.textTertiary.withOpacity(0.2)),
                   const SizedBox(height: 24),
                   Text("Your history is empty", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${orders.length} COMPLETED ORDERS", style: GoogleFonts.manrope(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.textTertiary, letterSpacing: 1.5)),
                    TextButton.icon(
                      onPressed: () => service.clearHistory(),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.error),
                      label: const Text("Clear All", style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildHistoryCard(order);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(OrderModel order) {
    final String mainId = order.orderCode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      mainId, 
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primaryBlue)
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ..._buildHistoryFileItems(mainId, [order]),
        ],
      ),
    );
  }

  List<Widget> _buildHistoryFileItems(String mainId, List<OrderModel> items) {
    List<Widget> widgets = [];
    int subIdx = 1;
    for (var order in items) {
      if (order.fileUrls.isEmpty) {
        widgets.add(_buildFileActionRow(mainId, subIdx++, order, fileIdx: 0));
      } else {
        for (int i = 0; i < order.fileUrls.length; i++) {
          widgets.add(_buildFileActionRow(mainId, subIdx++, order, fileIdx: i));
        }
      }
    }
    return widgets;
  }

  Widget _buildFileActionRow(String mainId, int subIdx, OrderModel order, {required int fileIdx}) {
    final fileName = order.fileNames.length > fileIdx ? order.fileNames[fileIdx] : order.fileName;
    final fileUrl = order.fileUrls.length > fileIdx ? order.fileUrls[fileIdx] : order.fileUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Document Set $subIdx", 
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _requirementLabel(order.getIsColor(fileIdx) ? "COLOR" : "B/W"),
              _requirementLabel(order.getIsDuplex(fileIdx) ? "2-SIDED" : "1-SIDE"),
              _requirementLabel("${order.getCopies(fileIdx)} COPIES"),
              _requirementLabel("${order.getPageCount(fileIdx)} PAGES"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requirementLabel(String text) {
    return Text(
      text, 
      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 0.5)
    );
  }
}
