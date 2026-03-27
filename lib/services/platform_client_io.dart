
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class PlatformClient {
  static http.Client getClient() {
    final ioc = HttpClient();
    ioc.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }
}
