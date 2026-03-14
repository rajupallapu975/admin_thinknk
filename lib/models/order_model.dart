import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String customerName;
  final String fileName;
  final int bwPages;
  final int colorPages;
  final bool isDuplex;
  final String status; // 'pending', 'printing', 'ready', 'completed'
  final String paymentStatus; // 'done', 'pending', 'refunded'
  final double amount;
  final DateTime timestamp;
  final String? fileUrl;
  final String orderCode; // 4-digit code from customer app
  final DateTime? printedAt;
  final String? lastPrinterUsed;

  bool get isImageFile {
    final name = fileName.toLowerCase();
    return name.endsWith('.jpg') || 
           name.endsWith('.jpeg') || 
           name.endsWith('.png') || 
           name.endsWith('.webp') || 
           name.endsWith('.gif');
  }

  OrderModel({
    required this.id,
    required this.customerName,
    required this.fileName,
    required this.bwPages,
    required this.colorPages,
    required this.isDuplex,
    required this.status,
    required this.paymentStatus,
    required this.amount,
    required this.timestamp,
    required this.orderCode,
    this.fileUrl,
    this.printedAt,
    this.lastPrinterUsed,
  });

  factory OrderModel.fromMap(Map<String, dynamic> data, String docId) {
    return OrderModel(
      id: docId,
      customerName: data['customerName'] ?? 'Guest',
      fileName: data['fileName'] ?? 'document.pdf',
      bwPages: data['bwPages'] ?? 0,
      colorPages: data['colorPages'] ?? 0,
      isDuplex: data['isDuplex'] ?? false,
      status: data['status'] ?? 'pending',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      amount: (data['amount'] ?? 0.0).toDouble(),
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate() 
          : data['timestamp'] != null 
              ? DateTime.parse(data['timestamp'].toString()) 
              : DateTime.now(),
      fileUrl: data['fileUrl'] ?? data['url'] ?? data['imageUrl'] ?? data['cloudinaryUrl'] ?? 
              (data['fileUrls'] is List && (data['fileUrls'] as List).isNotEmpty ? data['fileUrls'][0] : null),
      orderCode: data['orderCode']?.toString() ?? 
                data['xeroxId']?.toString() ??
                (docId.length >= 4 ? docId.substring(docId.length - 4).toUpperCase() : docId.toUpperCase()),
      printedAt: data['printedAt'] is Timestamp ? (data['printedAt'] as Timestamp).toDate() : null,
      lastPrinterUsed: data['lastPrinterUsed'],
    );
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel.fromMap(json, json['id']?.toString() ?? '');
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerName': customerName,
      'fileName': fileName,
      'bwPages': bwPages,
      'colorPages': colorPages,
      'isDuplex': isDuplex,
      'status': status,
      'paymentStatus': paymentStatus,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
      'fileUrl': fileUrl,
      'orderCode': orderCode,
    };
  }

  int get totalPages => bwPages + colorPages;
}
