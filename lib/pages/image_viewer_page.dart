import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

class ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  final String? downloadUrl;
  final String fileName;

  const ImageViewerPage({super.key, required this.imageUrl, this.downloadUrl, required this.fileName});

  Future<Uint8List> _fetchPdf() async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to load PDF from Cloudinary API.');
    }
  }

  @override
  Widget build(BuildContext context) {
    String finalUrl = imageUrl;
    final String lowerName = fileName.toLowerCase();
    final String lowerUrl = imageUrl.toLowerCase();
    
    // Improved detection: If it has an image extension in the URL, it's NOT a PDF (even if filename is misleading)
    final bool hasImageExt = lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg') || 
                             lowerUrl.contains('.png') || lowerUrl.contains('.webp');
    
    final bool isPdf = !hasImageExt && (lowerName.endsWith('.pdf') || lowerUrl.contains('.pdf'));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open externally',
              onPressed: () => launchUrl(Uri.parse(downloadUrl ?? imageUrl), mode: LaunchMode.externalApplication),
          ),
        ],    
      ),
      body: isPdf 
        ? PdfPreview(
            build: (format) => _fetchPdf(),
            allowPrinting: true,
            allowSharing: true,
            useActions: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            padding: EdgeInsets.zero,
            pdfFileName: fileName,
          )
        : Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                finalUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 80),
                      const SizedBox(height: 16),
                      const Text("Preview not available", style: TextStyle(color: Colors.white54, fontSize: 16)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(downloadUrl ?? imageUrl), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text("Download Original"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24, 
                          foregroundColor: Colors.white,
                        ),
                      )
                    ],
                  );  
                },
              ),
            ),
          ),
    );
  }
}
