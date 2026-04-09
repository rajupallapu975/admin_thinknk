import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WebDownloader {
  /// ⬇️ Downloads a file in the browser with a specific name
  static Future<void> downloadFile(String url, String fileName) async {
    if (!kIsWeb) return;
    
    try {
      // 1. Fetch the data as a Blob via JS to avoid CORS issues if possible, 
      // or just fetch via HTTP if CORS is allowed.
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Download failed: ${response.statusCode}');
      
      final bytes = response.bodyBytes;
      
      // 2. Trigger JS to create blob and download
      // We use js.context.callMethod instead of direct dart:html to avoid non-web compilation errors
      js.context.callMethod('eval', [
        """
        (function(bytes, filename) {
          const blob = new Blob([new Uint8Array(bytes)], { type: 'application/octet-stream' });
          const url = window.URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.style.display = 'none';
          a.href = url;
          a.download = filename;
          document.body.appendChild(a);
          a.click();
          window.URL.revokeObjectURL(url);
          document.body.removeChild(a);
        })(${bytes.toList()}, '$fileName')
        """
      ]);
    } catch (e) {
      debugPrint('❌ WebDownloader Error: $e');
      throw e;
    }
  }
}
