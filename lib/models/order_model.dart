import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String customerName;
  final String fileName;
  final int bwPages;
  final int colorPages;
  final bool isDuplex;
  final String orderStatus; 
  final String paymentStatus; 
  final double amount;
  final DateTime timestamp;
  final String? fileUrl;
  final List<String> fileUrls;
  final String orderCode; 
  final int copies;
  final String? lastPrinterUsed;
  final String orientation; 
  final String? customerPhone;
  final List<String> fileNames;
  final List<Map<String, dynamic>> fileSettings;
  final List<String> viewUrls;
  
  OrderModel({
    required this.id,
    required this.customerName,
    required this.fileName,
    required this.bwPages,
    required this.colorPages,
    required this.isDuplex,
    required this.orderStatus,
    required this.paymentStatus,
    required this.amount,
    required this.timestamp,
    required this.orderCode,
    this.fileNames = const [],
    this.fileUrls = const [],
    this.fileSettings = const [],
    this.viewUrls = const [],
    this.orientation = 'portrait',
    this.copies = 1,
    this.fileUrl,
    this.lastPrinterUsed,
    this.customerPhone,
    this.customId,
  });

  final String? customId;

  // 🛠️ RESTORED Helper methods from original code
  bool getIsColor(int index) {
    if (index < 0 || index >= fileSettings.length) return colorPages > 0;
    final color = fileSettings[index]['color']?.toString().toUpperCase();
    return color == 'COLOR';
  }

  bool getIsDuplex(int index) {
    if (index < 0 || index >= fileSettings.length) return isDuplex;
    return fileSettings[index]['doubleSided'] == true || fileSettings[index]['isDoubleSided'] == true;
  }

  String getOrientation(int index) {
    if (index < 0 || index >= fileSettings.length) return orientation;
    return fileSettings[index]['orientation']?.toString().toLowerCase() ?? orientation;
  }

  int getCopies(int index) {
    if (index < 0 || index >= fileSettings.length) return copies;
    return (fileSettings[index]['copies'] ?? copies) as int;
  }

  int getPageCount(int index) {
    if (index >= 0 && index < fileSettings.length) {
       return (fileSettings[index]['pageCount'] ?? 1) as int;
    }
    if (index >= 0 && index < fileNames.length) {
       final name = fileNames[index].toLowerCase();
       final isImg = name.endsWith('.jpg') || name.endsWith('.jpeg') || 
                     name.endsWith('.png') || name.endsWith('.webp');
       if (isImg) { return 1; }
    }
    if (fileUrls.length == 1) { return totalPages; }
    return 1; 
  }

  int get totalPages => bwPages + colorPages;

  factory OrderModel.fromMap(Map<String, dynamic> data, String docId) {
    List<String> urls = [];
    if (data['fileUrls'] is List) urls = List<String>.from(data['fileUrls']);
    else if (data['urls'] is List) urls = List<String>.from(data['urls']);
    else if (data['imageUrls'] is List) urls = List<String>.from(data['imageUrls']);
    
    // Fallback for single URLs
    String? singleUrl = data['fileUrl'] ?? data['url'] ?? data['imageUrl'];
    if (urls.isEmpty && singleUrl != null) urls = [singleUrl];

    List<String> views = [];
    if (data['viewUrls'] is List) views = List<String>.from(data['viewUrls']);
    if (views.isEmpty && urls.isNotEmpty) views = urls; // Fallback to fileUrls if viewUrls missing

    List<Map<String, dynamic>> settingsList = [];
    final printSettings = data['printSettings'];
    if (printSettings is Map && printSettings['files'] is List) {
      settingsList = (printSettings['files'] as List).cast<Map<String, dynamic>>();
    }

    // 🥇 Prioritize overall completion status for the Admin Tab to prevent "sticky" active items
    final String rawStatus = (data['status']?.toString() ?? '').toLowerCase().trim();
    final String rawOrderStatus = (data['orderStatus']?.toString() ?? '').toLowerCase().trim();
    
    String finalStatus = 'not printed yet';
    if (rawStatus == 'completed' || rawStatus == 'order completed' || rawOrderStatus == 'order completed' || rawOrderStatus == 'completed') {
       finalStatus = 'order completed';
    } else if (rawOrderStatus.isNotEmpty) {
       finalStatus = rawOrderStatus;
    } else if (rawStatus.isNotEmpty) {
       finalStatus = rawStatus;
    }
    
    return OrderModel(
      id: docId,
      customerName: data['customerName'] ?? 'Guest',
      fileName: data['fileName'] ?? 'document.pdf',
      bwPages: data['bwPages'] ?? 0,
      colorPages: data['colorPages'] ?? 0,
      isDuplex: data['isDuplex'] ?? false,
      orderStatus: finalStatus,
      paymentStatus: data['paymentStatus'] ?? 'pending',
      amount: (data['amount'] ?? 0.0).toDouble(),
      orientation: data['orientation'] ?? 'portrait',
      copies: data['numCopies'] ?? data['copies'] ?? 1,
      fileUrls: urls,
      fileNames: data['fileNames'] is List ? List<String>.from(data['fileNames']) : [],
      fileSettings: settingsList,
      viewUrls: views,
      customerPhone: data['customerPhone']?.toString(),
      timestamp: data['timestamp'] is Timestamp ? (data['timestamp'] as Timestamp).toDate() : DateTime.now(),
      fileUrl: data['fileUrl'] ?? (urls.isNotEmpty ? urls[0] : null),
      orderCode: data['orderCode']?.toString() ?? docId,
      customId: data['customId']?.toString(),
    );
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel.fromMap(json, json['id']?.toString() ?? json['orderId']?.toString() ?? '');
  }
}
