import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../image_viewer_page.dart';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';

import '../../utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../order_details_page.dart';
import '../../services/printer_service.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class HomeTab extends StatefulWidget {
  final AppUser user;
  const HomeTab({super.key, required this.user});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final Set<String> _completedBatches = {};
  final Set<String> _expandedBatches = {};

  @override
  void initState() {
    super.initState();
    _cleanupExpiredOrders();
  }

  Future<void> _cleanupExpiredOrders() async {
    try {
      final now = DateTime.now();
      final expirationDate = now.subtract(const Duration(hours: 24));
      
      final shopRef = _firestore.collection('shops').doc(widget.user.uid);
      
      // 🕵️ Get potential victims in shop subcollection
      final snapshot = await shopRef.collection('orders')
          .where('timestamp', isLessThan: Timestamp.fromDate(expirationDate))
          .get();

      final victims = snapshot.docs.where((doc) {
        final status = doc.get('status');
        // Only delete if it's not a legacy completed order (keep those for wallet history unless too old)
        return status != 'completed';
      }).toList();

      if (victims.isNotEmpty) {
        final batch = _firestore.batch();
        
        // 🏗️ PSFC Account access
        final psfcApp = Firebase.app('psfc');
        final psfcFirestore = FirebaseFirestore.instanceFor(app: psfcApp);
        final psfcBatch = psfcFirestore.batch();

        for (var doc in victims) {
          batch.delete(doc.reference);
          
          // Waterfall delete across all PSFC collections
          for (var col in ['xerox_shop_orders', 'xerox_orders', 'orders']) {
             psfcBatch.delete(psfcFirestore.collection(col).doc(doc.id));
          }
        }

        await Future.wait([
          batch.commit(),
          psfcBatch.commit().catchError((_) => null), // Silent if already gone
        ]);
        debugPrint("🗑️ Cascade cleaned up ${victims.length} expired orders.");
      }
    } catch (e) {
      debugPrint("Cleanup Error: $e");
    }
  }






  @override
  Widget build(BuildContext context) {
    final shopRef = _firestore.collection('shops').doc(widget.user.uid);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Active Orders",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900, 
            fontSize: isDesktop ? 32 : 24,
            letterSpacing: -1
          )
        ),
        actions: [
          _buildQuickWallet(shopRef),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double horizontalPadding = constraints.maxWidth > 800 ? constraints.maxWidth * 0.1 : 16;
          
          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: shopRef.collection('orders')
                      .where('paymentStatus', isEqualTo: 'done')
                      .where('status', whereIn: ['pending', 'active'])
                      .where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24))))
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                     if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                     
                     var orders = snapshot.data?.docs.map((doc) => OrderModel.fromFirestore(doc)).toList() ?? [];
                     
                      // 📦 Grouping Logic: Aggregate by Main Ticket ID (orderCode)
                      Map<String, List<OrderModel>> grouped = {};
                      for (var o in orders) {
                        grouped.putIfAbsent(o.orderCode, () => []).add(o);
                      }
                      final sortedKeys = grouped.keys.toList();

                      if (orders.isEmpty && _searchQuery.isEmpty) return _buildEmptyState();

                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: AppColors.softShadow,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (value) => setState(() => _searchQuery = value),
                                    decoration: const InputDecoration(
                                      hintText: "Search by Ticket ID (e.g. 6042)...",
                                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                                      border: InputBorder.none,
                                      icon: Icon(Icons.search_rounded, color: AppColors.primaryBlue, size: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Text(
                                      _searchQuery.isEmpty ? "${sortedKeys.length} ACTIVE BATCHES (${orders.length} ITEMS)" : "MATCHING BATCHES (${sortedKeys.length})",
                                      style: GoogleFonts.manrope(
                                        fontSize: constraints.maxWidth > 800 ? 12 : 10, 
                                        fontWeight: FontWeight.w900, 
                                        color: AppColors.textTertiary,
                                        letterSpacing: 1
                                      )
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, gridConstraints) {
                                final isDesktopGrid = gridConstraints.maxWidth > 800;
                                final columns = gridConstraints.maxWidth > 1200 ? 3 : (isDesktopGrid ? 2 : 1);
                                
                                if (!isDesktopGrid) {
                                  return ListView.builder(
                                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                                    itemCount: sortedKeys.length,
                                    itemBuilder: (context, index) {
                                      final mainId = sortedKeys[index];
                                      return _buildMainOrderGroup(mainId, grouped[mainId]!);
                                    },
                                  );
                                }

                                return SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    crossAxisAlignment: WrapCrossAlignment.start,
                                    children: sortedKeys.map((mainId) {
                                      final items = grouped[mainId]!;
                                      final itemWidth = (gridConstraints.maxWidth - (horizontalPadding * 2) - (16 * (columns - 1))) / columns;
                                      return SizedBox(
                                        width: itemWidth - 1, 
                                        child: _buildMainOrderGroup(mainId, items),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                   },
                 ),
               ),
             ],
           );
         },
       ),
     );
   }

  Widget _buildQuickWallet(DocumentReference shopRef) {
    return StreamBuilder<DocumentSnapshot>(
      stream: shopRef.snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final balance = (data['walletBalance'] ?? 0.0).toDouble();
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              "₹${balance.toInt()}",
              style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainOrderGroup(String mainId, List<OrderModel> items) {
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final rawName = items.first.customerName;
    // Format name to hide email domain if present
    final String customerName = rawName.contains('@') ? rawName.split('@').first : rawName;
    final totalAmount = items.fold(0.0, (val, o) => val + o.amount);
    final int totalFiles = items.fold(0, (sum, o) => sum + (o.fileUrls.isNotEmpty ? o.fileUrls.length : 1));
    final bool isCompleted = _completedBatches.contains(mainId);
    final bool isExpanded = _expandedBatches.contains(mainId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key("group_$mainId"),
        direction: DismissDirection.endToStart,
        background: Container(
          padding: const EdgeInsets.only(right: 20),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_forever_rounded, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text("DELETE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Delete Batch?"),
              content: Text("Delete ALL orders under Ticket #$mainId? This will also remove them from the User's active list."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text("DELETE BATCH"),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) async {
           final batch = _firestore.batch();
           final psfcApp = Firebase.app('psfc');
           final psfcFirestore = FirebaseFirestore.instanceFor(app: psfcApp);
           final psfcBatch = psfcFirestore.batch();
           final shopRef = _firestore.collection('shops').doc(widget.user.uid);

           for (var order in items) {
             batch.delete(shopRef.collection('orders').doc(order.id));
             for (var col in ['xerox_shop_orders', 'xerox_orders', 'orders']) {
               psfcBatch.delete(psfcFirestore.collection(col).doc(order.id));
             }
           }

           await Future.wait([
             batch.commit(),
             psfcBatch.commit().catchError((_) => null),
           ]);
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ticket #$mainId deleted and synced."), backgroundColor: Colors.black));
           }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isExpanded 
              ? AppColors.primaryBlue.withValues(alpha: 0.08) 
              : (isCompleted ? Colors.green.withValues(alpha: 0.05) : AppColors.surface),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isExpanded 
                ? AppColors.primaryBlue 
                : (isCompleted ? Colors.green.withValues(alpha: 0.3) : AppColors.border), 
              width: isExpanded ? 2.0 : 1.2
            ),
            boxShadow: isExpanded ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))] : AppColors.softShadow,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey(mainId),
              onExpansionChanged: (val) {
                setState(() {
                  if (val) {
                    _expandedBatches.add(mainId);
                  } else {
                    _expandedBatches.remove(mainId);
                  }
                });
              },
              initiallyExpanded: isExpanded,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isExpanded 
                    ? AppColors.primaryBlue 
                    : (isCompleted ? Colors.green : AppColors.primaryBlue.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  mainId, 
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900, 
                    fontSize: 16, 
                    color: (isExpanded || isCompleted) ? Colors.white : AppColors.primaryBlue
                  )
                ),
              ),
              title: Text(
                customerName.toUpperCase(), 
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900, 
                  fontSize: 15, 
                  color: isExpanded ? AppColors.primaryBlue : AppColors.textPrimary, 
                  letterSpacing: 0.5
                )
              ),
              subtitle: Row(
                children: [
                  Text("$totalFiles File${totalFiles > 1 ? 's' : ''}", style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.bold, color: isExpanded ? AppColors.primaryBlue.withValues(alpha: 0.7) : AppColors.textTertiary)),
                  const SizedBox(width: 8),
                  Text("• ₹${totalAmount.toInt()}", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: isExpanded ? AppColors.primaryBlue : AppColors.primaryBlue)),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      if (isCompleted) {
                        setState(() {
                          _completedBatches.remove(mainId);
                        });
                      } else {
                        _showMarkDoneDialog(mainId, items);
                      }
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green : (isExpanded ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.background),
                        shape: BoxShape.circle,
                        border: Border.all(color: isCompleted ? Colors.green : (isExpanded ? AppColors.primaryBlue : AppColors.border), width: 2),
                      ),
                      child: Icon(
                        Icons.done_all_rounded, 
                        size: 24, 
                        color: isCompleted ? Colors.white : (isExpanded ? AppColors.primaryBlue : AppColors.textTertiary)
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isExpanded ? AppColors.primaryBlue : AppColors.textTertiary,
                  ),
                ],
              ),
              children: [
                const Divider(height: 1, indent: 20, endIndent: 20),
                Container(
                  color: AppColors.background.withValues(alpha: 0.5),
                  child: Column(
                    children: [
                      ..._buildFlattenedFileItems(mainId, items),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }

  void _showMarkDoneDialog(String mainId, List<OrderModel> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Mark Print Done?", style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        content: Text(
          "Are you sure you want to mark Ticket #$mainId as completely printed?\n\n"
          "Note: When your print is done and confirmed, it will move into the Completed / Pending history page.",
          style: GoogleFonts.manrope(fontSize: 14, color: AppColors.textSecondary)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              // 🛡️ 1. Capture ScaffoldMessenger and Navigator state BEFORE any async/pop work
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              
              // 🛡️ 2. Briefly capture context-dependent values
              final shopUid = widget.user.uid;
              final backendUrl = dotenv.env['BACKEND_URL'] ?? 'https://thinkink-backend.onrender.com';

              debugPrint("🚀 Double Tick Clicked: Items count: ${items.length}");
              
              navigator.pop(); // Close the dialog
              
              setState(() {
                _completedBatches.add(mainId);
              });

              // Brief delay to let user see it turn green
              await Future.delayed(const Duration(milliseconds: 600));

              // 🏗️ 3. Initialize PSFC for direct sync
              FirebaseFirestore? psfcFirestore;
              try {
                final psfcApp = Firebase.app('psfc');
                psfcFirestore = FirebaseFirestore.instanceFor(app: psfcApp);
              } catch (_) { /* ignore if not available */ }

              final List<Future<void>> updates = [];
              
              try {
                for (var order in items) {
                  // 🚀 ACTION LOG
                  debugPrint("🔵 Action: Starting update for Ticket: ${order.orderCode} (Doc: ${order.id})");

                  updates.add(() async {
                    try {
                      bool psfcDirectSuccess = false;

                      // 🏗️ A. Direct Sync (PSFC)
                      if (psfcFirestore != null) {
                        try {
                           debugPrint("📡 Attempting Direct PSFC Sync for ${order.id}...");
                           final List<String> userAppCols = ['xerox_shop_orders', 'xerox_orders', 'orders'];
                           for (var col in userAppCols) {
                             await psfcFirestore.collection(col).doc(order.id).update({
                                'orderStatus': 'printing completed',
                                // 💡 We DON'T set status: 'completed' here, 
                                // so it STAYS visible in the User App's Active list.
                             }).catchError((_) => null);
                           }
                           psfcDirectSuccess = true;
                           debugPrint("✅ Direct PSFC Sync SUCCESS for ${order.id}");
                        } catch (e) {
                           debugPrint("⚠️ Direct PSFC Sync failed: $e. Falling back to backend...");
                        }
                      }

                      // 🏗️ B. Fallback Sync via Backend Proxy
                      if (!psfcDirectSuccess) {
                        try {
                          debugPrint("📡 Syncing via Backend Proxy ($backendUrl) for ${order.id}...");
                          final response = await http.post(
                            Uri.parse('$backendUrl/mark-printed'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({'orderId': order.id}),
                          ).timeout(const Duration(seconds: 10));
                          
                          if (response.statusCode == 200) {
                            debugPrint("✅ Backend Sync SUCCESS for ${order.id}");
                          } else {
                            debugPrint("❌ Backend Sync FAILED (${response.statusCode}) for ${order.id}");
                          }
                        } catch (e) {
                          debugPrint("❌ Backend Sync ERROR for ${order.id}: $e");
                        }
                      }

                      // 🏗️ C. Local Shop Record Update (Admin Display)
                      try {
                        await _firestore.collection('shops').doc(shopUid).collection('orders').doc(order.id).update({
                           'orderStatus': 'printing completed',
                           'status': 'ready', // Jumps out of Home Tab and into Deliveries
                           'timestamp': FieldValue.serverTimestamp(), 
                        });
                        debugPrint("✅ Local Shop Record updated for ${order.id}");
                        debugPrint("🚀 STATUS CHECK: Order ${order.id} is now 'printing completed'. Moving to Deliveries.");
                      } catch (e) {
                        debugPrint("❌ Local Shop update failure for ${order.id}: $e");
                      }
                    } catch (e) {
                      debugPrint("❌ Batch task crash for ${order.id}: $e");
                    }
                  }());
                }

                if (updates.isNotEmpty) {
                  await Future.wait(updates);
                }

                if (mounted) {
                   scaffoldMessenger.showSnackBar(const SnackBar(
                    content: Text("Print confirmed! Moved to Deliveries."), 
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ));
                }
              } catch (e) {
                debugPrint("❌ Batch Process Error: $e");
                if (mounted) {
                  scaffoldMessenger.showSnackBar(SnackBar(
                    content: Text("Sync Issues: Check Backend Connection"), 
                    backgroundColor: Colors.red
                  ));
                  setState(() {
                    _completedBatches.remove(mainId);
                  });
                }
              }
            },
            child: Text("PRINT DONE", style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFlattenedFileItems(String mainId, List<OrderModel> items) {
    List<Widget> fileWidgets = [];
    int globalSubIdx = 1;
    
    // Protect against duplicate documents in the same snapshot
    final Set<String> processedDocIds = {};

    for (var order in items) {
      if (processedDocIds.contains(order.id)) continue;
      processedDocIds.add(order.id);

      // Handle single file (legacy or simple xerox) or multi-file cases
      if (order.fileUrls.isEmpty) {
        fileWidgets.add(_buildSubOrderItem(mainId, globalSubIdx++, order, fileIdx: 0));
      } else {
        for (int i = 0; i < order.fileUrls.length; i++) {
          fileWidgets.add(_buildSubOrderItem(mainId, globalSubIdx++, order, fileIdx: i));
        }
      }
    }
    return fileWidgets;
  }

  Widget _buildSubOrderItem(String mainId, int subIdx, OrderModel order, {required int fileIdx}) {
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
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                 decoration: BoxDecoration(
                   color: AppColors.error.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(6),
                 ),
                 child: Text("#$mainId-$subIdx", style: GoogleFonts.inter(fontSize: isSmallScreen ? 9 : 10, fontWeight: FontWeight.w900, color: AppColors.error)),
               ),
               const Spacer(),
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: order.orderStatus == 'printing completed' ? Colors.green.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(6),
                 ),
                 child: Text(
                   order.orderStatus.toUpperCase(),
                   style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: order.orderStatus == 'printing completed' ? Colors.green : AppColors.error),
                 ),
               ),
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
          
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              _symbolChip(
                order.getIsColor(fileIdx) ? Icons.palette : Icons.contrast, 
                order.getIsColor(fileIdx) ? "COLOR" : "B/W"
              ),
              if (order.getIsDuplex(fileIdx))
                _symbolChip(Icons.copy_all, "2-SIDED"),
              _symbolChip(Icons.filter_none_rounded, "${order.getCopies(fileIdx)} COPIES"),
              _chipIf(true, order.getOrientation(fileIdx).contains('landscape') ? Icons.landscape : Icons.portrait, order.getOrientation(fileIdx).toUpperCase()),
              _chipIf(true, Icons.description_outlined, "${order.getPageCount(fileIdx)} ${order.getPageCount(fileIdx) == 1 ? 'PAGE' : 'PAGES'}"),
            ],
          ),
          const SizedBox(height: 20),
          // ACTIONS
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                        if (fileUrl == null) return;
                        String dlUrl = fileUrl;
                        // 📥 FORCE DOWNLOAD FOR CLOUDINARY WITH ORIGINAL FILENAME
                        if (dlUrl.contains('cloudinary.com') && dlUrl.contains('/upload/')) {
                           final safeName = Uri.encodeComponent(fileName.split('.').first.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_'));
                           dlUrl = dlUrl.replaceFirst('/upload/', '/upload/fl_attachment:$safeName/');
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Downloading securely in the background... check notifications."),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ));

                        await launchUrl(Uri.parse(dlUrl), mode: LaunchMode.externalApplication);
                    },
                    icon: Icon(Icons.download_rounded, size: isSmallScreen ? 16 : 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("DOWNLOAD", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: isSmallScreen ? 11 : 13))
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (fileUrl == null) return;
                      final isImage = ['.jpg', '.jpeg', '.png', '.webp', '.gif'].any((ext) => fileName.toLowerCase().endsWith(ext));
                      
                      if (isImage) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerPage(imageUrl: fileUrl, fileName: fileName)));
                      } else {
                        launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: Icon(Icons.visibility_rounded, size: isSmallScreen ? 16 : 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("VIEW", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: isSmallScreen ? 11 : 13))
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // SECONDARY MORE DETAILS
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsPage(order: order, shopId: widget.user.uid))),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  "VIEW FULL CONFIGURATION", 
                  style: GoogleFonts.inter(fontSize: isSmallScreen ? 9 : 10, fontWeight: FontWeight.w900, color: AppColors.textTertiary, letterSpacing: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipIf(bool condition, IconData icon, String label) {
    if (!condition) return const SizedBox.shrink();
    return _symbolChip(icon, label);
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'printing':
        color = AppColors.primaryBlue;
        label = "PRINTING";
        icon = Icons.sync;
        break;
      case 'ready':
        color = AppColors.success;
        label = "READY";
        icon = Icons.check_circle_outline;
        break;
      default:
        color = AppColors.warning;
        label = "NEW ORDER";
        icon = Icons.fiber_new_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _symbolChip(IconData? icon, String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 12, color: AppColors.textSecondary),
          if (icon != null) const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showPrintConfirmation(OrderModel order) {
    final printerService = Provider.of<PrinterService>(context, listen: false);
    final printerName = printerService.primaryPrinter ?? "Default System Printer";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.print_rounded, color: AppColors.primaryBlue, size: 32),
            ),
            const SizedBox(height: 16),
            Text("Print Job Overview", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("FILE: ${order.fileName}", style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 24),
            _diagRow(Icons.print_outlined, "Destination", printerName),
            _diagRow(Icons.description_outlined, "Paper size", "A4"),
            _diagRow(Icons.filter_none_rounded, "Copies", "${order.copies}"),
            _diagRow(Icons.landscape_rounded, "Orientation", order.orientation.toUpperCase()),
            _diagRow(Icons.color_lens_rounded, "Pages", "${order.totalPages} (${order.colorPages > 0 ? 'Color' : 'B/W'})"),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Ensure A4 paper is loaded. This job will be sent directly to the spooler.",
                      style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("CANCEL", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.textTertiary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      printerService.handleDirectPrint(order, widget.user.uid);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text("PRINT", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.manrope(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primaryBlue)),
        ],
      ),
    );
  }


  




  Widget _buildEmptyState() {
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Container(
             padding: const EdgeInsets.all(24),
             decoration: BoxDecoration(
               color: AppColors.surface,
               shape: BoxShape.circle,
               boxShadow: AppColors.softShadow,
             ),
             child: const Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.primaryBlue),
           ),
           const SizedBox(height: 24),
           Text(
             "All Clear!",
             style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)
           ),
           const SizedBox(height: 8),
           Text(
             "No active orders found in the queue.",
             style: GoogleFonts.manrope(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)
           ),
         ],
       ),
     );
  }
}
