import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_colors.dart';

// 🛡️ High-fidelity top-level background handler for Android (Closed App state)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🚀 Handling a background message: ${message.messageId}");
}

class GlobalNotificationService {
  static final GlobalNotificationService _instance = GlobalNotificationService._internal();
  factory GlobalNotificationService() => _instance;
  GlobalNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isInitialized = false;
  String? _shopId;
  final DateTime _startTime = DateTime.now();

  Future<void> init(BuildContext context, String shopId) async {
    if (_isInitialized) return;
    _shopId = shopId;
    _isInitialized = true;

    // 🔔 FCM Infrastructure setup (Background alerts support)
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      
      // 🛡️ Sync FCM Token for backend-triggered closed-app notifications
      // VAPID key is required for Web background support (if using customized FCM VAPID)
      final String? token = await messaging.getToken();
      if (token != null) {
        await _firestore.collection('shops').doc(shopId).update({'fcmToken': token});
        debugPrint("📡 FCM Token Synced for closed-state alerts: $token");
      }
      
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null) {
             _triggerAlert(context, message.notification!.title ?? "Order Update", message.notification!.body ?? "Check your shop dashboard.");
          }
      });
    } catch (e) {
      debugPrint("FCM initialization failed: $e");
    }

    // Foreground Listeners (Keep existing real-time logic for active app)

    // 1. Listen for NEW PAID ORDERS (Customer -> Shop)
    _firestore.collection('shops').doc(shopId).collection('orders')
        .where('paymentStatus', isEqualTo: 'done')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          if (timestamp != null && timestamp.isAfter(_startTime)) {
            _triggerAlert(context, "New Order Received! 📥", "A customer just paid for a scan/print.");
          }
        }
      }
    });

    // 2. Listen for COMPLETED PAYOUTS (Admin -> Shop)
    _firestore.collection('withdrawal_requests')
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'paid')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>;
          final timestamp = (data['requestedAt'] as Timestamp?)?.toDate();
          // We check if it's recently paid to avoid historical alerts
          if (data['status'] == 'paid' && timestamp != null && timestamp.isAfter(_startTime.subtract(const Duration(minutes: 5)))) {
             _triggerAlert(context, "Payout Completed! 💰", "₹${data['amount']} has been sent to your bank.");
          }
        }
      }
    });
  }

  void _triggerAlert(BuildContext context, String title, String subtitle) {
    // Show persistent snackbar or custom overlay
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(subtitle, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryBlue,
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(label: "VIEW", textColor: Colors.white, onPressed: () {
             // Navigation could happen here if needed
          }),
        ),
      );
    }
  }
}
