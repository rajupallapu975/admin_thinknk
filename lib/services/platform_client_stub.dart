
import 'package:http/http.dart' as http;

abstract class PlatformClient {
  static http.Client getClient() => throw UnsupportedError('Cannot create a client without platform implementation');
}
