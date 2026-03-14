import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';

enum PrinterStatus { connected, disconnected, connecting }

class PrinterService extends ChangeNotifier {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  PrinterStatus _status = PrinterStatus.disconnected;
  final List<String> _connectedPrinters = [];
  final Map<String, Printer> _printerObjects = {}; 
  String? _primaryPrinter;
  
  // Printing Progress State (For HP/Canon like experience)
  bool _isJobActive = false;
  double _jobProgress = 0.0; // 0.0 to 1.0
  String _jobStatusMessage = "";
  
  // Persistence for "Resume Print" feature
  OrderModel? _pendingResumptionOrder;
  String? _pendingShopId;

  PrinterStatus get status => _status;
  List<String> get connectedPrinters => _connectedPrinters;
  String? get primaryPrinter => _primaryPrinter;
  bool get isConnected => _connectedPrinters.isNotEmpty;
  bool get hasPendingJob => _pendingResumptionOrder != null;
  
  bool get isJobActive => _isJobActive;
  double get jobProgress => _jobProgress;
  String get jobStatusMessage => _jobStatusMessage;

  Future<void> connectPrinter(Object nameOrPrinter, String shopId) async {
    String name;
    if (nameOrPrinter is Printer) {
      name = nameOrPrinter.name;
      _printerObjects[name] = nameOrPrinter;
    } else {
      name = nameOrPrinter.toString();
    }

    if (_connectedPrinters.contains(name)) return;

    _status = PrinterStatus.connecting;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1)); 
      if (!_connectedPrinters.contains(name)) {
        _connectedPrinters.add(name);
      }
      _primaryPrinter = name;
      _status = PrinterStatus.connected;
      
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'activePrinters': _connectedPrinters.length,
      });

      if (_pendingResumptionOrder != null && _pendingShopId == shopId) {
        final order = _pendingResumptionOrder!;
        final sid = _pendingShopId!;
        _pendingResumptionOrder = null;
        _pendingShopId = null;
        Future.delayed(const Duration(milliseconds: 500), () => handleDirectPrint(order, sid));
      }

    } catch (e) {
      debugPrint("Sync Error: $e");
    }
    
    notifyListeners();
  }

  void setPrimaryPrinter(String name) {
    if (_connectedPrinters.contains(name)) {
      _primaryPrinter = name;
      notifyListeners();
    }
  }

  Future<void> disconnectPrinter(String name, String shopId) async {
    _connectedPrinters.remove(name);
    _printerObjects.remove(name);
    if (_primaryPrinter == name) {
      _primaryPrinter = _connectedPrinters.isNotEmpty ? _connectedPrinters.last : null;
    }
    if (_connectedPrinters.isEmpty) {
      _status = PrinterStatus.disconnected;
    }

    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'activePrinters': _connectedPrinters.length,
      });
    } catch (e) {
      debugPrint("Sync Error: $e");
    }

    notifyListeners();
  }

  /// ONE-CLICK WORKFLOW: Fully Automatic Handover with "Deals" (Settings)
  Future<void> handleDirectPrint(OrderModel order, String shopId) async {
    if (!isConnected) {
      _pendingResumptionOrder = order;
      _pendingShopId = shopId;
      notifyListeners();
      return;
    }

    _isJobActive = true;
    _jobProgress = 0.05;
    _jobStatusMessage = "Initializing auto-print engine...";
    notifyListeners();

    try {
      // 1. RE-DISCOVER PRINTER IF OBJECT IS LOST (e.g. after app restart)
      if (_primaryPrinter != null && !_printerObjects.containsKey(_primaryPrinter)) {
        _jobStatusMessage = "Searching for ${_primaryPrinter}...";
        notifyListeners();
        final systemPrinters = await Printing.listPrinters();
        final found = systemPrinters.firstWhere(
          (p) => p.name == _primaryPrinter,
          orElse: () => systemPrinters.isNotEmpty ? systemPrinters.first : throw "Printer ${_primaryPrinter} not found on network."
        );
        _printerObjects[found.name] = found;
        _primaryPrinter = found.name;
      }

      if (order.fileUrl == null) throw "File URL is missing.";
      
      _jobStatusMessage = "Fetching document context...";
      _jobProgress = 0.15;
      notifyListeners();
      
      final response = await http.get(Uri.parse(order.fileUrl!));
      if (response.statusCode != 200) throw "Fetch failed. Check network.";
      final bytes = response.bodyBytes;

      _jobStatusMessage = "Encoding for ${order.colorPages > 0 ? 'COLOR' : 'B/W'} ${order.isDuplex ? '(2-SIDED)' : ''}";
      _jobProgress = 0.4;
      notifyListeners();

      final String fileName = order.fileName.toLowerCase();
      final bool isPDF = fileName.endsWith('.pdf');
      Uint8List pdfData;

      if (isPDF) {
        pdfData = bytes;
      } else {
        final pdf = pw.Document();
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
        pdfData = await pdf.save();
      }

      _jobProgress = 0.7;
      _jobStatusMessage = "Handshaking with hardware...";
      notifyListeners();

      final Printer? printer = _primaryPrinter != null ? _printerObjects[_primaryPrinter] : null;

      bool success = false;
      
      // AUTO-PRINT LOGIC FOR PC & MOBILE
      if (printer != null) {
        try {
          // Attempt Direct Print (Silent)
          success = await Printing.directPrintPdf(
            printer: printer,
            onLayout: (PdfPageFormat format) async => pdfData,
            name: order.fileName,
          );
        } catch (e) {
          debugPrint("Silent print failed: $e");
          // Fallback to layout if direct fail
          success = await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfData,
            name: order.fileName,
            usePrinterSettings: true, // This allows 'deals' from system defaults
          );
        }
      } else {
        // No specific printer, use system dialog but keep settings
        success = await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfData,
          name: order.fileName,
          usePrinterSettings: true,
        );
      }

      if (success) {
        _jobProgress = 1.0;
        _jobStatusMessage = "PRINT CONFIRMED: ${order.orderCode}";
        notifyListeners();
        
        final db = FirebaseFirestore.instance;
        final orderRef = db.collection('shops').doc(shopId).collection('orders').doc(order.id);
        
        await orderRef.update({
          'status': 'printing',
          'printedAt': FieldValue.serverTimestamp(),
          'lastPrinterUsed': _primaryPrinter ?? "System Default",
          'printType': order.colorPages > 0 ? "Color" : "B/W",
          'isDuplex': order.isDuplex
        });
        
        await Future.delayed(const Duration(seconds: 1));
      } else {
        _jobStatusMessage = "User cancelled the print job.";
        _jobProgress = 0.0;
        notifyListeners();
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      _jobStatusMessage = "HARDWARE FAULT: $e";
      _jobProgress = 0.0;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 3));
    } finally {
      _isJobActive = false;
      _jobProgress = 0.0;
      _jobStatusMessage = "";
      notifyListeners();
    }
  }
}
