/// Bellekte tutan [DeviceSessionStore] — testler diske ve platform
/// kanallarına dokunmasın.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:mutfakapp/src/data/device_session.dart';

class FakeDeviceSessionStore implements DeviceSessionStore {
  FakeDeviceSessionStore({String? baseUrl, String? token})
    : _baseUrl = baseUrl {
    if (token != null) tokens.write(token);
  }

  String? _baseUrl;

  @override
  final TokenStore tokens = InMemoryTokenStore();

  @override
  Future<DeviceSession> read({required String fallbackBaseUrl}) async =>
      DeviceSession(
        baseUrl: _baseUrl ?? fallbackBaseUrl,
        token: await tokens.read(),
      );

  @override
  Future<void> writeBaseUrl(String baseUrl) async => _baseUrl = baseUrl;

  @override
  Future<void> clearToken() => tokens.clear();

  /// Testin doğrulaması için: kaydedilmiş adres.
  String? get savedBaseUrl => _baseUrl;
}
