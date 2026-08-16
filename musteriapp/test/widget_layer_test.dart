/// Bileşen katmanının İKİ TEMADA da çizilebildiğini sınar.
///
/// **Neden bu test var:** marka rolleri bir `ThemeExtension` üzerinden
/// okunuyor ve `context.bld` kayıtlı olmayan bir temada BİLEREK patlıyor.
/// Bir bileşen rolü unutup ham sabite dönerse ya da yeni bir bileşen uzantıyı
/// kayıtsız bir temada okursa, bu koşu onu ilk karede yakalar. Koyu tema
/// henüz kullanıcıya kapalı (`app.dart`), ama kapalı olması bozuk olmasını
/// haklı çıkarmaz — açılacağı gün tek satırla açılabilmeli.
///
/// Her bileşen ayrıca `RenderFlex overflow` gibi düzen istisnalarına karşı
/// gerçekten yerleştiriliyor: `pumpWidget` bir düzen istisnasında testi
/// düşürür.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteriapp/src/core/eta_text.dart';
import 'package:musteriapp/src/theme/bld_theme.dart';
import 'package:musteriapp/src/l10n/app_localizations.dart';
import 'package:musteriapp/src/widgets/bld_card.dart';
import 'package:musteriapp/src/widgets/empty_view.dart';
import 'package:musteriapp/src/widgets/eta_notice.dart';
import 'package:musteriapp/src/widgets/menu_photo_grid.dart';
import 'package:musteriapp/src/widgets/money_text.dart';
import 'package:musteriapp/src/widgets/network_food_image.dart';
import 'package:musteriapp/src/widgets/order_cutoff_countdown.dart';
import 'package:musteriapp/src/widgets/pill.dart';
import 'package:musteriapp/src/widgets/section_header.dart';
import 'package:musteriapp/src/widgets/skeletons.dart';
import 'package:musteriapp/src/widgets/status_views.dart';
import 'package:musteriapp/src/widgets/stock_pill.dart';

const _eta = EtaPresentation(
  title: 'Tahmini teslim',
  value: '40-55 dakika · 12:55-13:10 arası',
  sourceNote: 'Mutfak yoğunluğuna göre hesaplandı.',
  busyNote: 'Bugün yoğunuz, süre uzayabilir.',
);

/// Katmanın tamamı — bir ekranın çizebileceği her bileşen bir arada.
///
/// `ListView` DEĞİL `SingleChildScrollView` + `Column`: tembel liste yalnız
/// görünen çocukları kurar ve ekranın altında kalan bileşenler hiç
/// çizilmeden test yeşil dönerdi.
Widget _gallery() => SingleChildScrollView(
  padding: const EdgeInsets.all(BldSpacing.md),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(title: 'Bugünün menüsü', actionLabel: 'Tümü'),
      const BldCard(child: Text('Dokunulamayan kart')),
      const SizedBox(height: BldSpacing.sm),
      BldCard(
        level: BldSurfaceLevel.raised,
        onTap: () {},
        child: const Text('Dokunulabilir kart'),
      ),
      const SizedBox(height: BldSpacing.sm),
      const Wrap(
        spacing: BldSpacing.sm,
        children: [
          BldPill(label: 'Marka', variant: BldPillVariant.brand),
          BldPill(label: 'Nötr'),
          BldPill(label: 'Bilgi', variant: BldPillVariant.info),
          BldPill(label: 'Başarılı', variant: BldPillVariant.success),
          BldPill(label: 'Uyarı', variant: BldPillVariant.warning),
          BldPill(label: 'Hata', variant: BldPillVariant.danger),
        ],
      ),
      const SizedBox(height: BldSpacing.sm),
      const Row(
        children: [
          MoneyText(41000),
          SizedBox(width: BldSpacing.sm),
          MoneyText.previous(52000),
          SizedBox(width: BldSpacing.sm),
          MoneyText(-4550, scale: MoneyScale.sm, tone: MoneyTone.credit),
        ],
      ),
      const SizedBox(height: BldSpacing.sm),
      // Stok rozetinin DÖRT bandı da: sınırsız ve bolluk hiç çizilmiyor,
      // ikisi de galeride sessiz kalmalı.
      Wrap(
        spacing: BldSpacing.sm,
        children: const [
          StockPill(remaining: null),
          StockPill(remaining: 42),
          StockPill(remaining: 3),
          StockPill(remaining: 0),
        ],
      ),
      const SizedBox(height: BldSpacing.sm),
      // Geri sayımın iki hâli: bir günden uzak (mutlak an) ve son bir saat
      // (uyarı tonu). Zamanlayıcı testin sonunda `dispose` ile iptal edilmezse
      // koşu "pending timer" ile düşer — bu galeri onu da sınıyor.
      OrderCutoffCountdown(
        cutoffAt: DateTime.now().toUtc().add(const Duration(days: 3)),
      ),
      OrderCutoffCountdown(
        cutoffAt: DateTime.now().toUtc().add(const Duration(minutes: 40)),
      ),
      const SizedBox(height: BldSpacing.sm),
      // Izgaranın 1/2/3/4 yerleşimi — dördü de kurulmalı, hiçbiri taşmamalı.
      for (final count in [0, 1, 2, 3, 4])
        Padding(
          padding: const EdgeInsets.only(bottom: BldSpacing.sm),
          child: MenuPhotoGrid(
            imageUrls: [
              for (var index = 0; index < count; index++)
                'https://ornek.test/yemek$index.jpg',
            ],
          ),
        ),
      const EtaNotice(eta: _eta),
      const SizedBox(height: BldSpacing.sm),
      const OfflineBanner(message: 'Çevrimdışısınız.'),
      const SizedBox(height: BldSpacing.sm),
      const FormErrorBox(message: 'Gönderilen bilgilerde eksik alan var.'),
      const SizedBox(height: BldSpacing.sm),
      const SizedBox(height: 160, child: NetworkFoodImage(url: null)),
      const SizedBox(height: BldSpacing.sm),
      const MenuCardSkeleton(),
      const ListRowSkeleton(count: 2),
      const LoadingView(rows: 2),
      for (final tone in BldStatusTone.values)
        SizedBox(
          height: 320,
          child: EmptyView(
            tone: tone,
            icon: Icons.receipt_long_outlined,
            title: 'Burada henüz bir şey yok',
            message: 'Sipariş verdiğinizde geçmişiniz burada görünecek.',
            actionLabel: 'Menüye git',
            onAction: () {},
          ),
        ),
    ],
  ),
);

void main() {
  for (final (name, theme) in [
    ('açık', BldTheme.light()),
    ('koyu', BldTheme.dark()),
  ]) {
    testWidgets('$name temada bileşen katmanının tamamı çizilir', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          // Bileşenlerin bir kısmı metnini `l10n`'dan alıyor (stok rozeti,
          // geri sayım); delegeler olmadan galeri ilk karede patlar.
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _gallery()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // Galerinin gerçekten çizildiğinin kanıtı: bileşenlerden birkaçı
      // ağaçta olmalı, yoksa boş bir liste de "istisna yok" derdi.
      expect(find.byType(BldCard), findsNWidgets(2));
      // Altı anlamsal rozet + stok rozetinin ÇİZİLEN iki bandı ("son 3
      // porsiyon" ve "tükendi"); sınırsız ve bolluk sessiz.
      expect(find.byType(BldPill), findsNWidgets(8));
      expect(find.text('Son 3 porsiyon'), findsOneWidget);
      expect(find.text('Tükendi'), findsOneWidget);
      expect(find.text('410,00 ₺'), findsOneWidget);
      // Üç durum tonunun ÜÇÜ de kuruldu — ekranın altında kalanlar dahil.
      expect(
        find.byType(EmptyView),
        findsNWidgets(BldStatusTone.values.length),
      );
    });
  }
}
