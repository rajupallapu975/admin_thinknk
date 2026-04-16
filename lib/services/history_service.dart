import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryService extends ChangeNotifier {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _orderSubscription;
  final List<OrderModel> _history = [];
  List<OrderModel> get history => _history;
  
  // Track active orders to detect when they are removed (delivered)
  final Map<String, OrderModel> _activeTracker = {};

  static const String _storageKey = 'admin_order_history';

  Future<void> init() async {
    await loadHistory();
  }

  void startListening(String shopId) {
    _orderSubscription?.cancel();
    _orderSubscription = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('orders')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final order = OrderModel.fromFirestore(change.doc);
        
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          _activeTracker[order.id] = order;
          
          // 🛡️ If order is marked as completed, save to history immediately
          if (order.orderStatus.toLowerCase().trim() == 'order completed') {
            saveOrder(order);
          }
        } 
        else if (change.type == DocumentChangeType.removed) {
          // 🛡️ If an order is REMOVED from Firebase, it means it was DELIVERED
          final cached = _activeTracker[order.id];
          if (cached != null) {
            saveOrder(cached);
            _activeTracker.remove(order.id);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  Future<void> saveOrder(OrderModel order) async {
    // 🛡️ Avoid duplicates
    if (_history.any((o) => o.id == order.id)) return;

    _history.insert(0, order);
    
    await _persist();
    notifyListeners();
  }

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_storageKey);
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        _history.clear();
        _history.addAll(decoded.map((json) => OrderModel.fromJson(json)).toList());
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    }
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_history.map((o) => o.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint("Error persisting history: $e");
    }
  }
}
