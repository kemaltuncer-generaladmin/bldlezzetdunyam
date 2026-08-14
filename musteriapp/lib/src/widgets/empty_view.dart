/// Boş / hata / çevrimdışı durumlarının ORTAK düzeni.
///
/// **Neden üç durum tek bileşen:** üçü de aynı şeyi yapıyor — ekran
/// doldurulamadı, nedenini söyle ve bir çıkış yolu ver. Ayrı ayrı yazıldıkça
/// biri 88 px daire, biri 48 px ikon, biri başlıksız oldu ve aynı uygulamanın
/// üç ayrı ürününden çıkmış gibi göründüler. Değişen tek şey TON: renk, ekran
/// okuyucuya verilen rol ve eylemin ağırlığı.
///
/// Düzen: 72 px daire + 28 px ikon + h3 başlık + gövde mesajı (en fazla 42
/// karakter genişliğinde) + eylem.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../theme/bld_semantic_colors.dart';

/// Durum tonu — renk, ekran okuyucu rolü ve eylemin ağırlığı bundan gelir.
enum BldStatusTone {
  /// Liste boş. Bir HATA DEĞİL: ekran okuyucuya duyurulmaz, çünkü kullanıcı
  /// zaten oraya kendisi geldi ve başlık ona okunacak.
  empty,

  /// İstek başarısız. Ekran okuyucuya ANINDA duyurulur.
  error,

  /// Ağ yok / önbellekten geliniyor. Duyurulur ama hata gibi değil.
  offline,
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tone = BldStatusTone.empty,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final BldStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bld = context.bld;

    // Renkler ROL tablosundan geliyor, ham palet sabitinden değil: `brand50`
    // üstünde `brand600` açık temada doğru, koyu temada okunmaz. Rol
    // tablosunun iki temada da geçerli eşleniği var.
    final (Color circle, Color mark) = switch (tone) {
      BldStatusTone.empty => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
      BldStatusTone.error => (bld.dangerBg, bld.dangerFg),
      BldStatusTone.offline => (bld.warningBg, bld.warningFg),
    };

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: mark),
        ),
        const SizedBox(height: BldSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        if (message != null) ...[
          const SizedBox(height: BldSpacing.sm),
          ConstrainedBox(
            // ~42 karakter. Daha uzun satırlar okunurken göz satır başını
            // kaybediyor; ortalanmış metinde bu daha da belirgin.
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: BldSpacing.lg),
          // Boş durumun eylemi bir DAVET (birincil); hata ve çevrimdışının
          // eylemi bir ONARIM denemesi (outline). Başarısız bir istekten
          // sonra ekrandaki en görünür şey "tekrar dene" olmamalı — asıl
          // mesele mesajın kendisi.
          if (tone == BldStatusTone.empty)
            FilledButton(onPressed: onAction, child: Text(actionLabel!))
          else
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    final body = Padding(
      padding: const EdgeInsets.all(BldSpacing.xl),
      child: Semantics(
        container: true,
        // `liveRegion`, ekran okuyucuda `role="alert"`/`role="status"`
        // karşılığıdır: içerik yerine geldiğinde kullanıcı odak
        // değiştirmeden duyar.
        liveRegion: tone != BldStatusTone.empty,
        child: content,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Yükseklik sınırsızsa (bir `ListView`'un çocuğu olarak) kaydırma
        // eklemek anlamsız; kapsayan liste zaten kaydırıyor.
        if (!constraints.hasBoundedHeight) return Center(child: body);

        // Sınırlıysa: yer varken ORTALA, yokken KAYDIR. Yalnız `Center`
        // kullanmak, yatay çevrilmiş bir telefonda ya da büyük yazı tipi
        // ayarında daire + başlık + mesaj + butonu kutuya sığmaz hâle
        // getiriyor ve alttaki EYLEM görünmez oluyordu — boş durumun tek
        // işlevi o eylem.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: body),
          ),
        );
      },
    );
  }
}
