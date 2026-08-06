/// Teslim süresi tahmininin arayüz metni — `Location.eta`.
///
/// Metnin kendisi `l10n`'dedir; burada olan yalnızca **hangi metnin**
/// seçileceğidir. Ayrı dosya olmasının nedeni bu seçimin dört ekranda da
/// birebir aynı olması ve widget ağacından bağımsız test edilebilmesidir.
library;

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';

/// Ekrana basılmaya hazır tahmin metinleri.
@immutable
class EtaPresentation {
  const EtaPresentation({
    required this.title,
    required this.value,
    required this.sourceNote,
    this.busyNote,
  });

  /// "Tahmini teslim" / "Tahmini hazır olma".
  final String title;

  /// "60-85 dakika · 13:15-13:40 arası".
  final String value;

  /// Tahminin nereden geldiğini açıklar. Yer darsa gizlenebilir; `value`
  /// içindeki "yaklaşık" öneki temkini zaten taşır.
  final String sourceNote;

  /// Mutfak yoğunsa nedeni. Yoksa `null`.
  ///
  /// **Neden ayrı alan:** bu, `sourceNote` gibi süslemeye değil, kullanıcının
  /// beklentisini değiştiren bir bilgi. Dar görünümde bile gösterilir.
  final String? busyNote;
}

/// Sipariş **verilmeden önceki** tahmin: menü, sepet, ödeme.
///
/// Çıpa [now]'dır — kullanıcı şimdi sipariş verirse yemek ne zaman gelir?
///
/// Ölçülmemiş tahminde ("configured", ya da sözleşmede olmayan bir kaynak)
/// bilinçli olarak "yaklaşık" öneki kullanılır ve açıklama satırı ölçülmediğini
/// söyler. Gerekçe: panelde girilen değer bir *hedeftir*, gözlem değil; onu
/// ölçülmüş bir süreyle aynı dille sunmak kullanıcıya tutamayacağımız bir söz
/// verir. Ölçülmüş tahminde önek düşer, çünkü orada elimizde gerçek veri var.
EtaPresentation etaBeforeOrder(
  EtaWindow eta,
  DeliveryType deliveryType,
  AppLocalizations l10n, {
  required DateTime now,
}) {
  final minutes = l10n.etaMinutesRange(eta.minMinutes, eta.maxMinutes);
  final window = TurkishTime.minuteWindow(now, eta.minMinutes, eta.maxMinutes);

  return EtaPresentation(
    title: deliveryType == DeliveryType.pickup
        ? l10n.etaPickupTitle
        : l10n.etaDeliveryTitle,
    value: eta.isMeasured
        ? l10n.etaValue(minutes, window)
        : l10n.etaValueApprox(minutes, window),
    sourceNote: eta.isMeasured ? l10n.etaMeasuredNote : l10n.etaConfiguredNote,
    busyNote: eta.busy ? l10n.etaBusyNote : null,
  );
}

/// Sipariş **verildikten sonraki** tahmin: sipariş takip ekranı.
///
/// Çıpa [orderCreatedAt]'tır, "şimdi" değil. Sipariş 20 dakika önce verildiyse
/// pencere de 20 dakika geridedir; "şimdi"den hesaplamak, saatin sipariş
/// bekledikçe ileri kaymasına ve tahminin hiç gerçekleşmemesine yol açardı.
///
/// Kalan dakikayı değil yalnızca saati gösteririz: sipariş verildikten sonra
/// kullanıcının sorusu "kaç dakika sürer" değil, "saat kaçta gelir"dir.
EtaPresentation etaAfterOrder(
  EtaWindow eta,
  DeliveryType deliveryType,
  AppLocalizations l10n, {
  required DateTime orderCreatedAt,
}) {
  final window = TurkishTime.minuteWindow(
    orderCreatedAt,
    eta.minMinutes,
    eta.maxMinutes,
  );

  return EtaPresentation(
    title: deliveryType == DeliveryType.pickup
        ? l10n.etaOrderPickupTitle
        : l10n.etaOrderPlacedTitle,
    value: l10n.etaOrderWindow(window),
    sourceNote: eta.isMeasured ? l10n.etaMeasuredNote : l10n.etaConfiguredNote,
    busyNote: eta.busy ? l10n.etaBusyNote : null,
  );
}
