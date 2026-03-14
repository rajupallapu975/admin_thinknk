import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

class ManageDevicesPage extends StatefulWidget {
  final User user;
  const ManageDevicesPage({super.key, required this.user});

  @override
  State<ManageDevicesPage> createState() => _ManageDevicesPageState();
}

class _ManageDevicesPageState extends State<ManageDevicesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Future<void> _togglePrinter(String docId, bool currentStatus) async {
    await _firestore
        .collection('shops')
        .doc(widget.user.uid)
        .collection('printers')
        .doc(docId)
        .update({'isOnline': !currentStatus});
  }

  Future<void> _deletePrinter(String docId) async {
    await _firestore
        .collection('shops')
        .doc(widget.user.uid)
        .collection('printers')
        .doc(docId)
        .delete();
  }

  void _showAddPrinterDialog() {
    String name = "";
    String type = "B/W";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("Add New Printer", style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: "Printer Name",
                  hintText: "e.g. Epson L3110",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => name = val,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: InputDecoration(
                  labelText: "Print Type",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ["B/W", "Color"]
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setDialogState(() => type = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (name.isNotEmpty) {
                  await _firestore
                      .collection('shops')
                      .doc(widget.user.uid)
                      .collection('printers')
                      .add({
                    'name': name,
                    'type': type,
                    'isOnline': true,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Manage Devices", style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('shops')
            .doc(widget.user.uid)
            .collection('printers')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final printers = snapshot.data?.docs ?? [];

          if (printers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.print_disabled_rounded, size: 80, color: AppColors.textTertiary.withValues(alpha: 0.2)),
                  const SizedBox(height: 24),
                  Text("No devices found", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text("Add your Xerox machines to show they are active.", style: GoogleFonts.manrope(color: AppColors.textTertiary)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _showAddPrinterDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("Add New Printer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: printers.length,
            itemBuilder: (context, index) {
              final p = printers[index].data() as Map<String, dynamic>;
              final docId = printers[index].id;
              final isOnline = p['isOnline'] ?? false;
              final type = p['type'] ?? 'B/W';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.softShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (type == 'Color' ? AppColors.warning : AppColors.primaryBlue).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        type == 'Color' ? Icons.palette : Icons.print_rounded,
                        color: type == 'Color' ? AppColors.warning : AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['name'] ?? 'Printer', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                          Text(type, style: GoogleFonts.manrope(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Switch.adaptive(
                          value: isOnline,
                          activeThumbColor: AppColors.success,
                          onChanged: (val) => _togglePrinter(docId, isOnline),
                        ),
                        Text(
                          isOnline ? "ONLINE" : "OFFLINE",
                          style: GoogleFonts.inter(
                            fontSize: 9, 
                            fontWeight: FontWeight.w900, 
                            color: isOnline ? AppColors.success : AppColors.textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: () => _deletePrinter(docId),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPrinterDialog,
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
