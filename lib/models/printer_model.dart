import 'package:cloud_firestore/cloud_firestore.dart';

class PrinterModel {
  final String id;
  final String name;
  final String type; // 'B/W' or 'Color'
  final bool isOnline;
  final double pricePerPage;
  final DateTime createdAt;

  PrinterModel({
    required this.id,
    required this.name,
    required this.type,
    this.isOnline = true,
    required this.pricePerPage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'isOnline': isOnline,
      'pricePerPage': pricePerPage,
      'createdAt': createdAt,
    };
  }

  factory PrinterModel.fromMap(Map<String, dynamic> map, String id) {
    return PrinterModel(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? 'B/W',
      isOnline: map['isOnline'] ?? true,
      pricePerPage: (map['pricePerPage'] ?? 0.0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
