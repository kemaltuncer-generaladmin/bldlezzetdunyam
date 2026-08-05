/// Yeni sipariş sesli uyarısı (`docs/05-mutfakapp.md` §3).
///
/// Ayrı bir arayüz olmasının sebebi testtir: sesi çalan kod platform
/// kanalına dokunur, testte sahtelenmesi gerekir. Ayrıca ayarlardaki
/// "ses açık/kapalı" şalteri tek bir yerden geçer.
library;

import 'dart:async';

import 'package:flutter/services.dart';

/// Yeni sipariş geldiğinde ötecek uyarı.
abstract interface class OrderAlert {
  /// Kısa uyarı sesi. Aynı anda üç sipariş düşse bile **bir kez** çalınır;
  /// bunu çağıran tarafın garanti etmesi gerekir.
  void ding();
}

/// Masaüstü sistem uyarı sesini çalar.
///
/// **Neden `assets/new_order.wav` değil:** doküman özel bir wav dosyası
/// öngörüyor ama wav çalmak yeni bir pub bağımlılığı (`audioplayers` vb.)
/// gerektiriyor ve bağımlılık eklemek karar gerektiriyor (AGENTS.md §6.3).
/// `SystemSound` bağımlılıksız çalışır ve mutfaktaki asıl işi görür:
/// personelin başını ekrana kaldırmasını sağlamak.
class SystemOrderAlert implements OrderAlert {
  const SystemOrderAlert();

  @override
  void ding() => unawaited(SystemSound.play(SystemSoundType.alert));
}

/// Ses kapalıyken kullanılır. Çağrıyı yutmak yerine ayrı bir tip olması,
/// "ses kapalı" kararının tek bir `if` yerine sağlayıcı seviyesinde
/// verilmesini sağlar.
class SilentOrderAlert implements OrderAlert {
  const SilentOrderAlert();

  @override
  void ding() {}
}
