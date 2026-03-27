
import 'package:http/http.dart' as http;

class PlatformClient {
  static http.Client getClient() {
    return http.Client();
  }
}
