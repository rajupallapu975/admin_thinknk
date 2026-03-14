import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

class ApiService {
  static final String _baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  // Create a client that allows self-signed certificates (ideal for local HTTPS)
  static http.Client get _client {
    final ioc = HttpClient();
    ioc.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  static Future<List<OrderModel>> getLiveOrders(String shopId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/orders?shopId=$shopId'),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        return data.map((item) => OrderModel.fromJson(item)).toList();
      } else {
        throw "Server error: ${response.statusCode}";
      }
    } catch (e) {
      debugPrint("Fetch Orders Error: $e");
      return [];
    }
  }

  static Future<bool> markOrderCompleted(String orderId, String shopId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/orders/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'orderId': orderId,
          'shopId': shopId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Update Order Status Error: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> getWalletSummary(String shopId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/wallet?shopId=$shopId'),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw "Server error: ${response.statusCode}";
      }
    } catch (e) {
      debugPrint("Fetch Wallet Error: $e");
      return {'balance': 0.0, 'totalBwPages': 0, 'totalColorPages': 0, 'transactions': []};
    }
  }

  static Future<bool> sendPrintSignal(String orderId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/print'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'orderId': orderId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Print signal error: $e");
      return false;
    }
  }
}
