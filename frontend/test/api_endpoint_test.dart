import 'package:flutter_test/flutter_test.dart';
import 'package:learn_anywhere/api_endpoint.dart';

void main() {
  test('debug iOS simulator redirects stale LAN endpoint to host loopback', () {
    expect(
      resolveSimulatorApi(
        'http://192.168.1.32:8084',
        simulator: true,
        debug: true,
      ),
      'http://127.0.0.1:8084',
    );
    for (final url in [
      'http://192.168.1.32:8084',
      'https://example.com',
      'http://127.0.0.1:8084',
    ]) {
      expect(resolveSimulatorApi(url, simulator: false, debug: true), url);
      expect(resolveSimulatorApi(url, simulator: true, debug: false), url);
    }
    expect(
      resolveSimulatorApi('https://example.com', simulator: true, debug: true),
      'https://example.com',
    );
  });
}
