import 'package:admin_thinkink/pages/image_viewer_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../order_details_page.dart';
import '../printer_connecting_page.dart';
import '../../services/printer_service.dart';
import 'package:provider/provider.dart';

class HomeTab extends StatefulWidget {
  final User user;
  const HomeTab({super.key, required this.user});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _cleanupExpiredOrders();
  }

  Future<void> _cleanupExpiredOrders() async {
    try {
      final now = DateTime.now();
      final expirationDate = now.subtract(const Duration(hours: 24));
      
      final expiredOrders = await _firestore
          .collection('shops')
          .doc(widget.user.uid)
          .collection('orders')
          .where('timestamp', isLessThan: Timestamp.fromDate(expirationDate))
          // Only delete orders that are not 'completed' or already processed
          .where('status', isNotEqualTo: 'completed')
          .get();

      if (expiredOrders.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in expiredOrders.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint("🗑️ Cleaned up ${expiredOrders.docs.length} expired orders.");
      }
    } catch (e) {
      debugPrint("Cleanup Error: $e");
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    try {
      await _firestore
          .collection('shops')
          .doc(widget.user.uid)
          .collection('orders')
          .doc(orderId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order deleted successfully."), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting order: $e"), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _startPrinting(OrderModel order) async {
    try {
      await _firestore
          .collection('shops')
          .doc(widget.user.uid)
          .collection('orders')
          .doc(order.id)
          .update({'status': 'printing'});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Job Moved to Printing Queue."), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
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
                      .where('status', whereIn: ['pending', 'ready'])
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                     if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                     
                     var orders = snapshot.data?.docs.map((doc) => OrderModel.fromFirestore(doc)).toList() ?? [];
                     
                     if (_searchQuery.isNotEmpty) {
                       orders = orders.where((o) => o.orderCode.contains(_searchQuery.toUpperCase())).toList();
                     }

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
                                     hintText: "Search by ORDER ID...",
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
                                     _searchQuery.isEmpty ? "${orders.length} ACTIVE ORDERS" : "MATCHING ORDERS (${orders.length})",
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
                           child: ListView.builder(
                             padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                             itemCount: orders.length,
                             itemBuilder: (context, index) => _buildOrderCard(orders[index]),
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

  Widget _buildOrderCard(OrderModel order) {
    final isImage = order.isImageFile && order.fileUrl != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: _statusBadge(order.status),
          title: Text(
            order.fileName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
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
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "${order.totalPages} Pages • ${DateFormat('hh:mm a').format(order.timestamp)}",
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: Text(
            "₹${order.amount.toInt()}",
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
          ),
          children: [
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isImage && order.fileUrl != null)
                  GestureDetector(
                    onTap: () {
                      if (order.fileUrl == null || order.fileUrl!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Error: No file URL found for this order."), backgroundColor: AppColors.error),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ImageViewerPage(
                            imageUrl: order.fileUrl!, 
                            fileName: order.fileName
                          )
                        )
                      );
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        color: AppColors.background,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            order.fileUrl!,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 20, color: AppColors.textTertiary),
                            loadingBuilder: (_, child, prog) => prog == null ? child : const CircularProgressIndicator(strokeWidth: 2),
                          ),
                          Positioned(
                            bottom: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                              child: const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                            child: const Icon(Icons.person, size: 12, color: AppColors.primaryBlue),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.customerName, 
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _symbolChip(order.bwPages > 0 ? Icons.contrast : null, "B/W"),
                          _symbolChip(order.colorPages > 0 ? Icons.palette : null, "COL"),
                          _symbolChip(order.isDuplex ? Icons.copy_all : null, "2-SIDED"),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final printerService = Provider.of<PrinterService>(context, listen: false);
                      if (!printerService.isConnected) {
                        printerService.handleDirectPrint(order, widget.user.uid);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterConnectingPage()));
                        return;
                      }
                      printerService.handleDirectPrint(order, widget.user.uid);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Print Started..."), backgroundColor: AppColors.primaryBlue),
                      );
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text("PRINT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (order.fileUrl == null || order.fileUrl!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Error: No file URL found."), backgroundColor: AppColors.error),
                        );
                        return;
                      }
                      if (isImage) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerPage(imageUrl: order.fileUrl!, fileName: order.fileName)));
                      } else {
                        launchUrl(Uri.parse(order.fileUrl!), mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: Icon(isImage ? Icons.image_search_rounded : Icons.description_rounded, size: 18),
                    label: Text(isImage ? "VIEW" : "FILE", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => OrderDetailsPage(order: order, shopId: widget.user.uid))
                    ),
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    if (icon == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
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
