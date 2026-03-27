
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';

enum PrinterStatus { connected, disconnected, connecting }
enum JobState { idle, queued, printing, completed, error }

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
  JobState _currentJobState = JobState.idle;
  String? _activeOrderId;
  
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
  JobState get currentJobState => _currentJobState;
  String? get activeOrderId => _activeOrderId;

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
  /// Now handles "Intermediate-free" flow by performing auto-connection internally.
  Future<void> handleDirectPrint(OrderModel order, String shopId) async {
    _isJobActive = true;
    _activeOrderId = order.id;
    _currentJobState = JobState.queued;
    _jobProgress = 0.01;
    _jobStatusMessage = "Initializing Print Engine...";
    notifyListeners();

    final db = FirebaseFirestore.instance;
    final orderRef = db.collection('shops').doc(shopId).collection('orders').doc(order.id);
    final shopRef = db.collection('shops').doc(shopId);

    try {
      // 0. Set status to 'printing' in Firestore to move it to Pending Page
      await orderRef.update({'status': 'printing'});

      _currentJobState = JobState.printing;
      notifyListeners();
      
      // 1. AUTO-CONNECT / DISCOVERY PHASE
      try {
        if (!isConnected || (_primaryPrinter != null && !_printerObjects.containsKey(_primaryPrinter))) {
          _jobStatusMessage = _primaryPrinter != null ? "Waking up $_primaryPrinter..." : "Searching for active printers...";
          _jobProgress = 0.05;
          notifyListeners();

          List<Printer> systemPrinters = [];
          
          if (kIsWeb) {
            _jobStatusMessage = "Web Mode: Linking to browser spooler...";
            notifyListeners();
          } else {
            systemPrinters = await Printing.listPrinters();
            if (systemPrinters.isEmpty) {
              _currentJobState = JobState.error;
              _isJobActive = true;
              _jobStatusMessage = "NO PRINTERS FOUND\nPlease check your WiFi connection.";
              notifyListeners();
              throw "NO_PRINTERS_FOUND";
            }
          }

          Printer? target;
          if (!kIsWeb) {
            if (_primaryPrinter != null) {
              target = systemPrinters.firstWhere(
                (p) => p.name == _primaryPrinter,
                orElse: () => systemPrinters.first,
              );
            } else {
              // Automatically pick the first available or default system printer
              target = systemPrinters.first;
            }

            _printerObjects[target.name] = target;
            _primaryPrinter = target.name;
            if (!_connectedPrinters.contains(target.name)) {
              _connectedPrinters.add(target.name);
            }
            
            shopRef.update({
              'activePrinters': _connectedPrinters.length,
            }).catchError((e) => debugPrint("🔥 FIREBASE_SYNC_ERROR: $e"));

            _jobStatusMessage = "Direct Link: ${target.name}";
          } else {
            _jobStatusMessage = "Web Mode: Handing over to Spooler";
          }
          _jobProgress = 0.1;
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        throw "DISCOVERY_STAGE: $e";
      }

      // 2. MULTI-FILE DOWNLOAD & TRANSMISSION PHASE
      bool overallSuccess = true;
      try {
        final List<String> targetUrls = order.fileUrls.isNotEmpty ? order.fileUrls : (order.fileUrl != null ? [order.fileUrl!] : []);
        
        if (targetUrls.isEmpty) throw "NO_FILES_TO_PRINT";

        for (int fileIndex = 0; fileIndex < targetUrls.length; fileIndex++) {
          final String currentUrl = targetUrls[fileIndex];
          if (currentUrl.isEmpty) {
            debugPrint("⚠️ Skipping empty URL at index $fileIndex");
            continue;
          }

          // Delay between DIFFERENT files to allow printer buffer to breathe
          if (fileIndex > 0) {
            _jobStatusMessage = "Preparing next file...";
            notifyListeners();
            await Future.delayed(const Duration(milliseconds: 1500));
          }

          _jobStatusMessage = "Downloading file ${fileIndex + 1} of ${targetUrls.length}...";
          _jobProgress = 0.2 + (0.3 * (fileIndex / targetUrls.length));
          notifyListeners();

          try {
            debugPrint("🌍 Downloading: $currentUrl");
            final response = await http.get(Uri.parse(currentUrl)).timeout(const Duration(seconds: 15));
            if (response.statusCode != 200) {
              throw "SERVER_RETURNED_${response.statusCode}";
            }
            final Uint8List fileBytes = response.bodyBytes;
            
            // Generate a unique filename for this specific file in the sequence
            final String ext = currentUrl.split('?').first.split('.').last.toLowerCase();
            final String currentFileName = "file_${fileIndex + 1}_${order.orderCode}.$ext";
            
            // CRITICAL FIX: Detect PDF based on the ACTUAL URL/Bytes, not just the first file's name
            final bool isPDF = ext == 'pdf' || currentUrl.toLowerCase().contains('.pdf');

            int copies = order.copies > 0 ? order.copies : 1;
            bool fileSuccess = false;

            // Internal helper to build PDF per file
            Future<Uint8List> buildPdf(PdfPageFormat printerFormat) async {
              final PdfPageFormat baseFormat = PdfPageFormat.a4;
              
              final isLandscape = order.orientation.toLowerCase().contains('landscape');
              final PdfPageFormat format = isLandscape ? baseFormat.landscape : baseFormat;

              debugPrint("🖨️ Printing File ${fileIndex + 1}: ${isPDF ? 'PDF' : 'IMAGE'} | Mode: ${isLandscape ? 'LANDSCAPE' : 'PORTRAIT'}");

              if (isPDF) return fileBytes;
              
              final pdf = pw.Document();
              final image = pw.MemoryImage(fileBytes);
              pdf.addPage(
                pw.Page(
                  pageFormat: format.copyWith(marginTop: 0, marginBottom: 0, marginLeft: 0, marginRight: 0),
                  build: (context) => pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
                  ),
                ),
              );
              return await pdf.save();
            }

            // Try Silent Bridge first (for each file)
            if (kIsWeb) {
              // ... web logic remains same ...
            }

            if (!fileSuccess) {
              final Printer? targetPrinter = _primaryPrinter != null ? _printerObjects[_primaryPrinter] : null;
              if (targetPrinter != null && !kIsWeb) {
                // Ensure the loop is executed for exactly the number of copies ordered
                for (int i = 0; i < copies; i++) {
                  _jobStatusMessage = "Printing ${fileIndex + 1}/${targetUrls.length} (Copy ${i + 1}/$copies)";
                  notifyListeners();
                  
                  final bool result = await Printing.directPrintPdf(
                    printer: targetPrinter,
                    onLayout: buildPdf,
                    name: currentFileName,
                  );
                  if (result) fileSuccess = true;
                  // Critical: Small delay between copies to prevent printer buffer issues
                  if (i < copies - 1) await Future.delayed(const Duration(milliseconds: 800));
                }
              } else {
                _jobStatusMessage = "Opening Spooler for file ${fileIndex + 1}...";
                notifyListeners();
                fileSuccess = await Printing.layoutPdf(
                  onLayout: buildPdf,
                  name: currentFileName,
                  usePrinterSettings: true,
                );
              }
            }
            
            if (!fileSuccess) overallSuccess = false;
          } catch (e) {
            debugPrint("❌ DOWNLOAD_ERROR: $e");
            throw "DOWNLOAD_FAILED_FILE_${fileIndex + 1}: $e";
          }
        }
      } catch (e) {
        throw "PRINT_PIPELINE: $e";
      }

      if (overallSuccess) {
        _currentJobState = JobState.completed;
        _jobProgress = 1.0;
        _jobStatusMessage = "SUCCESS: Job Queue Clear";
        notifyListeners();
        
        try {
          // 🚀 UPDATE STATUS: Mark as printed but NOT completed.
          // This moves or keeps it in the Pending Page for manual receipt confirmation.
          await orderRef.update({
            'status': 'printing',
            'printedAt': FieldValue.serverTimestamp(),
            'lastPrinterUsed': _primaryPrinter,
          });
          debugPrint("✅ Order ${order.id} sent to printer and status updated to 'printing'.");
        } catch (e) {
          debugPrint("🔥 POST_PRINT_SYNC_ERROR: $e");
        }
        
        await Future.delayed(const Duration(seconds: 2));
      } else {
        // 🚨 ROLLBACK: User cancelled or job failed transmission
        _currentJobState = JobState.error;
        _jobStatusMessage = "Job cancelled or failed. Reverting...";
        notifyListeners();
        
        await orderRef.update({'status': 'pending'}); // Bring it back to Home Page
        
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      _currentJobState = JobState.error;
      debugPrint("❌ PRINT_PIPELINE_ERROR: $e");
      _jobStatusMessage = "ERROR: $e";
      _jobProgress = 0.0;
      notifyListeners();
      
      // Attempt rollback if we were in the middle of it
      try {
        await orderRef.update({'status': 'pending'});
      } catch (_) {}
      
      await Future.delayed(const Duration(seconds: 5));
    } finally {
      _isJobActive = false;
      _activeOrderId = null;
      _currentJobState = JobState.idle;
      _jobProgress = 0.0;
      _jobStatusMessage = "";
      notifyListeners();
    }
  }
}

