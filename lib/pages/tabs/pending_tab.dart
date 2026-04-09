import 'dart:convert';

import 'package:admin_thinkink/utils/web_downloader.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../qr_scanner_page.dart';
import '../image_viewer_page.dart';  
import 'package:url_launcher/url_launcher.dart'; 

class PendingTab extends StatefulWidget {
  final AppUser user;
  const PendingTab({super.key, required this.user});

  @override
  State<PendingTab> createState() => _PendingTabState();
}

class _PendingTabState extends State<PendingTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _expandedBatches = {};

  Future<void> _clearCompletedOrders(List<OrderModel> completed) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History"),
        content: Text("Delete all ${completed.length} completed orders from this list?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Delete All"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final shopRef = _firestore.collection('shops').doc(widget.user.uid);
      final batch = _firestore.batch();
      
      // 🏗️ PSFC Account access
      final psfcApp = Firebase.app('psfc');
      final psfcFirestore = FirebaseFirestore.instanceFor(app: psfcApp);
      final psfcBatch = psfcFirestore.batch();

      for (var order in completed) {
        // 1. Delete from shop subcollection
        batch.delete(shopRef.collection('orders').doc(order.id));

        // 2. Cascade delete from central collections
        for (var col in ['xerox_shop_orders', 'xerox_orders', 'orders']) {
           psfcBatch.delete(psfcFirestore.collection(col).doc(order.id));
        }
      }

      try {
        await Future.wait([
          batch.commit(),
          psfcBatch.commit().catchError((_) => null), // Silently fail if PSFC docs don't exist
        ]);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("History cleared & synced."), backgroundColor: Colors.grey));
        }
      } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Partial cleanup error: $e"), backgroundColor: Colors.red));
         }
      }
    }
  }

  Future<void> _showScanDialog(String mainId, List<OrderModel> items) async {
    final orderId = items.first.id;
    final bool? scanResult = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QRScannerPage(expectedShopId: orderId)),
    );

    if (scanResult == true) {
      await _finalizeBatch(mainId, items);
    }
  }

  Future<void> _finalizeBatch(String mainId, List<OrderModel> items) async {
    final String? backendUrl = dotenv.env['BACKEND_URL'];
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      debugPrint("🚀 Finalizing Batch #$mainId via Backend (${items.length} items)...");

      // We process each order through the backend to ensure Wallet/Stats/Cleanup are triggered
      bool allSuccessful = true;
      for (var order in items) {
        try {
          final response = await http.post(
            Uri.parse('$backendUrl/mark-delivered'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'orderId': order.id,
              'shopId': widget.user.uid,
            }),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode != 200) {
            allSuccessful = false;
            debugPrint("❌ Backend Finalize FAILED for ${order.id}: ${response.body}");
          }
        } catch (e) {
          allSuccessful = false;
          debugPrint("❌ Backend Finalize ERROR for ${order.id}: $e");
        }
      }

      if (mounted) {
        if (allSuccessful) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Delivered & Wallet Updated! 🎉"), backgroundColor: AppColors.success));
        } else {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Warning: Some orders failed to sync with backend."), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      debugPrint("❌ Finalize Error: $e");
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text("Critical Error: $e"), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Deliveries", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.textPrimary, letterSpacing: -1)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          )
        ],
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('shops')
            .doc(widget.user.uid)
            .collection('orders')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24))))
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final allOrders = snapshot.data!.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
          
          // 🧩 STRICT Filtering with .trim() for maximum robustness:
          final pendingOrders = allOrders.where((o) => o.orderStatus.toLowerCase().trim() == 'printing completed').toList();
          final completedOrders = allOrders.where((o) => o.orderStatus.toLowerCase().trim() == 'order completed').toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;
              final padding = isDesktop ? 24.0 : 16.0;

              return ListView(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
                children: [
                  if (pendingOrders.isNotEmpty) ...[
                    _buildSectionHeader("ACTIVE DELIVERIES", Icons.delivery_dining_rounded, Colors.green),
                    const SizedBox(height: 16),
                    _buildResponsiveGrid(_groupAndBuildOrders(pendingOrders), constraints.maxWidth),
                    const SizedBox(height: 32),
                  ],
                  
                  if (completedOrders.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildSectionHeader("RECENTLY COMPLETED", Icons.check_circle_rounded, Colors.grey)),
                        TextButton.icon(
                          onPressed: () => _clearCompletedOrders(completedOrders),
                          icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.grey),
                          label: const Text("Clear All", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildResponsiveGrid(_groupAndBuildOrders(completedOrders, isCompleted: true), constraints.maxWidth),
                    const SizedBox(height: 16),
                  ],

                  if (pendingOrders.isEmpty && completedOrders.isEmpty)
                    _buildEmptyState(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildResponsiveGrid(List<Widget> children, double maxWidth) {
    if (maxWidth <= 800) {
      return Column(children: children);
    }

    final columns = maxWidth > 1200 ? 3 : 2;
    final spacing = 16.0;
    final itemWidth = (maxWidth - (32 + (spacing * (columns - 1)))) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: children.map((child) => SizedBox(width: itemWidth - 1, child: child)).toList(),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: color.withOpacity(0.2), thickness: 1)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Icon(Icons.hourglass_empty_rounded, size: 80, color: AppColors.textTertiary.withOpacity(0.2)),
          const SizedBox(height: 24),
          Text(
            "No active pending deliveries",
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text("Mark orders as DONE from Active Orders first.", style: GoogleFonts.manrope(color: AppColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  List<Widget> _groupAndBuildOrders(List<OrderModel> orders, {bool isCompleted = false}) {
    final Map<String, List<OrderModel>> grouped = {};
    for (var o in orders) {
      grouped.putIfAbsent(o.orderCode, () => []).add(o);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedKeys.map((mainId) => _buildMainOrderGroup(mainId, grouped[mainId]!, isCompleted: isCompleted)).toList();
  }

  Widget _buildMainOrderGroup(String mainId, List<OrderModel> items, {bool isCompleted = false}) {
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final rawName = items.first.customerName;
    final String customerName = rawName.contains('@') ? rawName.split('@').first : rawName;
    final totalAmount = items.fold(0.0, (val, o) => val + o.amount);
    final int totalFiles = items.fold(0, (sum, o) => sum + (o.fileUrls.isNotEmpty ? o.fileUrls.length : 1));
    final bool isExpanded = _expandedBatches.contains(mainId);

    // Dynamic color based on status: Active is Green, Completed is Grey
    final cardColor = isCompleted ? Colors.grey : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardColor.withOpacity(0.5), width: 1.5),
        boxShadow: AppColors.softShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (val) {
            setState(() {
              if (val) {
                _expandedBatches.add(mainId);
              } else {
                _expandedBatches.remove(mainId);
              }
            });
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              mainId, 
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)
            ),
          ),
          title: Text(
            customerName.toUpperCase(), 
            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary, letterSpacing: 0.5)
          ),
          subtitle: Row(
            children: [
              Text("$totalFiles File${totalFiles > 1 ? 's' : ''}", style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: cardColor.withOpacity(0.8))),
              const SizedBox(width: 8),
              Text("• ₹${totalAmount.toInt()}", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: cardColor)),
              if (isCompleted) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 10, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text("DELIVERED", style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          trailing: Icon(
            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: isCompleted ? Colors.grey : cardColor,
          ),
          children: [
            const Divider(height: 1, indent: 20, endIndent: 20),
            Container(
              color: cardColor.withValues(alpha: 0.02),
              child: Column(
                children: [
                  ..._buildFlattenedFileItems(mainId, items, isCompleted: isCompleted),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFlattenedFileItems(String mainId, List<OrderModel> items, {bool isCompleted = false}) {
    List<Widget> fileWidgets = [];
    int globalSubIdx = 1;

    // Use a Set to track processed document IDs to prevent duplication if the stream returns a dirty snapshot
    final Set<String> processedDocIds = {};

    for (var order in items) {
      if (processedDocIds.contains(order.id)) continue;
      processedDocIds.add(order.id);

      // 🛡️ Handle case where fileUrls is empty but a single file exists
      if (order.fileUrls.isEmpty) {
        fileWidgets.add(_buildSubOrderItem(mainId, globalSubIdx++, order, fileIdx: 0, isCompleted: isCompleted));
      } else {
        for (int i = 0; i < order.fileUrls.length; i++) {
          fileWidgets.add(_buildSubOrderItem(mainId, globalSubIdx++, order, fileIdx: i, isCompleted: isCompleted));
        }
      }
    }
    return fileWidgets;
  }

  Widget _buildSubOrderItem(String mainId, int subIdx, OrderModel order, {required int fileIdx, bool isCompleted = false}) {
    final fileName = order.fileNames.length > fileIdx ? order.fileNames[fileIdx] : order.fileName;
    final fileUrl = order.fileUrls.length > fileIdx ? order.fileUrls[fileIdx] : order.fileUrl;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 400;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                 decoration: BoxDecoration(
                   color: (isCompleted ? Colors.grey : AppColors.error).withOpacity(0.1),
                   borderRadius: BorderRadius.circular(6),
                 ),
                 child: Text("#$mainId-$subIdx", style: GoogleFonts.inter(fontSize: isSmallScreen ? 9 : 10, fontWeight: FontWeight.w900, color: isCompleted ? Colors.grey : AppColors.error)),
               ),
               const Spacer(),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(color: (isCompleted ? Colors.grey : Colors.green).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                 child: Text(isCompleted ? "COMPLETED" : "PRINTED", style: TextStyle(color: isCompleted ? Colors.grey : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
               )
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Icon(
                fileName.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                size: isSmallScreen ? 14 : 16, 
                color: fileName.toLowerCase().endsWith('.pdf') ? AppColors.error : AppColors.primaryBlue
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fileName, 
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: isSmallScreen ? 13 : 14, color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chipIf(order.getIsColor(fileIdx), Icons.palette, "COLOR"),
              _chipIf(!order.getIsColor(fileIdx), Icons.contrast, "B/W"),
              _chipIf(order.getIsDuplex(fileIdx), Icons.copy_all, "2-SIDED"),
              _chipIf(!order.getIsDuplex(fileIdx), Icons.description, "1-SIDE"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background, border: Border.all(color: AppColors.border.withOpacity(0.4)), borderRadius: BorderRadius.circular(4)
                ),
                child: Text(
                  "${order.getPageCount(fileIdx)} ${order.getPageCount(fileIdx) == 1 ? 'PAGE' : 'PAGES'}", 
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background, border: Border.all(color: AppColors.border.withOpacity(0.4)), borderRadius: BorderRadius.circular(4)
                ),
                child: Text(
                  "${order.getCopies(fileIdx)} COPY", 
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary)
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
             
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final url = (order.viewUrls.length > fileIdx ? order.viewUrls[fileIdx] : order.fileUrls[fileIdx]) ?? "";
                    if (url.isNotEmpty) {
                      try {
                         await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      } catch (e) {
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open preview: $e')));
                         }
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.visibility_rounded, size: 20, color: AppColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    if (fileUrl == null) return;
                    try {
                      final extension = fileName.contains('.') ? fileName.split('.').last : (fileUrl.split('.').last);
                      final downloadName = "${mainId}_$subIdx.$extension";
                      
                      if (kIsWeb) {
                        await WebDownloader.downloadFile(fileUrl, downloadName);
                      } else {
                        await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                      }
                    } catch (e) {
                      debugPrint('Direct download failed: $e');
                      try {
                        await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                      } catch (err) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $err')));
                        }
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.download_rounded, size: 20, color: AppColors.primaryBlue),
                  ),
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }

  Widget _chipIf(bool condition, IconData icon, String label) {
    if (!condition) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
