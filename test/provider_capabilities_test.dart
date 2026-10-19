// Фиксирует контракт возможностей провайдеров (FR §6), по которому UI гейтит
// операции: RSVP поддержан всеми провайдерами календаря.

import 'package:calenfi/domain/models/enums.dart';
import 'package:calenfi/domain/providers/provider_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forProvider отдаёт правильные caps', () {
    expect(ProviderCapabilities.forProvider(ProviderType.google).rsvp, isTrue);
    expect(ProviderCapabilities.forProvider(ProviderType.graph).rsvp, isTrue);
    expect(ProviderCapabilities.forProvider(ProviderType.ews).rsvp, isTrue);
    expect(ProviderCapabilities.forProvider(ProviderType.caldav).rsvp, isTrue);
  });

  test('crud есть у всех подключаемых провайдеров', () {
    for (final p in ProviderType.values) {
      expect(ProviderCapabilities.forProvider(p).crud, isTrue, reason: '$p');
    }
  });
}
