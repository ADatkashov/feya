import 'package:feya/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the demo backend is an https origin without a path', () {
    final uri = Uri.parse(AppConfig.demoApiBase);
    expect(uri.scheme, 'https');
    expect(uri.host, isNotEmpty);
    expect(uri.path, isEmpty);
  });

  test('api and media urls are built from the base origin', () {
    expect(AppConfig.apiUrl, '${AppConfig.apiBaseUrl}/api/v1');
    expect(
      AppConfig.resolveMedia('/media/a.jpg'),
      '${AppConfig.apiBaseUrl}/media/a.jpg',
    );
    expect(
      AppConfig.resolveMedia('https://x.test/a.jpg'),
      'https://x.test/a.jpg',
    );
    expect(AppConfig.resolveMedia(null), isNull);
  });
}
