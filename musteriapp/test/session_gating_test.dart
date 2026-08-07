/// B2B sipariş kapısının kaynağı `Session.canOrder`'dır (yönlendirici bunu
/// okur). Kural tek yerde: sunucunun `can_order` bayrağı; profil yoksa kapı
/// açık kalır (çevrimdışı açılışta kullanıcı kilitlenmez).
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/providers/session_provider.dart';

Customer _customer({bool canOrder = true, String accountType = 'corporate'}) =>
    Customer(
      id: 1,
      firstName: 'Veli',
      lastName: 'Ali',
      email: 'veli@firma.com',
      telephone: '5551234567',
      accountType: accountType,
      canOrder: canOrder,
      companyName: 'Firma A.Ş.',
    );

void main() {
  test('profil yoksa kapı açık (grandfather güvencesi)', () {
    const session = Session(isSignedIn: true);
    expect(session.canOrder, isTrue);
  });

  test('sunucu can_order=true ise sipariş verebilir', () {
    final session = Session(isSignedIn: true, customer: _customer());
    expect(session.canOrder, isTrue);
  });

  test('sunucu can_order=false ise sipariş veremez', () {
    final session = Session(
      isSignedIn: true,
      customer: _customer(canOrder: false),
    );
    expect(session.canOrder, isFalse);
  });

  test('kurumsal hesap isCorporate ile ayırt edilir', () {
    final corporate = _customer();
    final individual = _customer(accountType: 'individual');
    expect(corporate.isCorporate, isTrue);
    expect(individual.isCorporate, isFalse);
  });
}
