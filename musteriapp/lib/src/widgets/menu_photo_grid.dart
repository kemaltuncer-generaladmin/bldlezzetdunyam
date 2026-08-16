/// Menü kartının görsel ızgarası — `DailyMenu.image_urls` (2×2).
///
/// Menünün ilk dört kaleminin fotoğrafı tek bir kapak alanında dizilir
/// (`AGENTS.md` iş kuralı 6). Dizilim **istemcide** yapılıyor, sunucuda değil:
/// ızgara bir görüntüleme kararıdır ve dar bir kartta 1×2'ye düşebilir.
/// Hangi görsellerin geleceğine ve kapağın ızgaraya tercih edilip
/// edilmeyeceğine karar veren yer `DailyMenu.cardImageUrls`'tir — o seçim
/// sözleşmenin bir cümlesi ve bu widget onu yeniden yorumlamaz, aldığı listeyi
/// dizer.
///
/// ## Yerleşim ÇAPRAZ PLATFORM SÖZLEŞMEDİR
///
/// Aynı gün webde ve uygulamada aynı kartla çıkmalı; yer tutucunun geometrisi
/// (`WheatArcPlaceholder` / `website/components/product-image.tsx`) zaten
/// sözleşme sayılıyor ve hücre düzeni onun devamı. Kural, görsel sayısına
/// göre:
///
/// - **0** → tek hücre, yer tutucu (görselsiz gün de kart çizer)
/// - **1** → tek hücre, kabın tamamı
/// - **2** → yan yana iki eşit sütun (soldan sağa)
/// - **3** → SOLDA tam boy bir hücre, SAĞDA üst üste iki hücre
/// - **4** → 2×2; ilk iki görsel üst satır, sonraki ikisi alt satır
///
/// Üçlü dizilimde ilk görselin büyük olması bilinçli: yönetici kalemleri
/// önem sırasına göre giriyor ve ana yemek listenin başında duruyor.
///
/// Dörtten fazlası **çizilmez**; sunucu zaten dörtle sınırlıyor, kısıt burada
/// da var ki bozuk bir yanıt ızgarayı taşırmasın.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import 'network_food_image.dart';

class MenuPhotoGrid extends StatelessWidget {
  const MenuPhotoGrid({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 16 / 9,
    this.radius = BldRadius.md,
  });

  /// Dizilecek görseller, yöneticinin verdiği sırada. Boş liste yer tutucudur.
  final List<String> imageUrls;

  /// Izgaranın tamamının oranı — hücrelerin kendi oranı yoktur, alanı
  /// bölüşürler.
  final double aspectRatio;

  /// Dış köşe yarıçapı. Kartın üstüne oturuyorsa çağıran `0` verip kendi
  /// `ClipRRect`'ini kullanır.
  final double radius;

  /// Hücreler arasındaki boşluk.
  ///
  /// Kart zemininin ince bir çizgi hâlinde görünmesini sağlar; sıfır olsaydı
  /// iki koyu fotoğraf tek bir görsele yapışırdı.
  static const double gap = 2;

  /// Sunucunun da uyguladığı üst sınır.
  static const int maxCells = 4;

  @override
  Widget build(BuildContext context) {
    final urls = imageUrls.take(maxCells).toList(growable: false);

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: switch (urls.length) {
          0 => const _Cell(url: null),
          1 => _Cell(url: urls[0]),
          2 => _Row(children: [_Cell(url: urls[0]), _Cell(url: urls[1])]),
          3 => _Row(
            children: [
              _Cell(url: urls[0]),
              _Column(children: [_Cell(url: urls[1]), _Cell(url: urls[2])]),
            ],
          ),
          _ => _Column(
            children: [
              _Row(children: [_Cell(url: urls[0]), _Cell(url: urls[1])]),
              _Row(children: [_Cell(url: urls[2]), _Cell(url: urls[3])]),
            ],
          ),
        },
      ),
    );
  }
}

/// Eşit paylı yatay bölüm; araya [MenuPhotoGrid.gap] koyar.
class _Row extends StatelessWidget {
  const _Row({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(width: MenuPhotoGrid.gap),
        Expanded(child: children[index]),
      ],
    ],
  );
}

/// Eşit paylı dikey bölüm.
class _Column extends StatelessWidget {
  const _Column({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(height: MenuPhotoGrid.gap),
        Expanded(child: children[index]),
      ],
    ],
  );
}

/// Tek bir hücre — kendisine verilen alanı doldurur.
///
/// Yer tutucu ve yükleme durumu [NetworkFoodImage]'ın kendi işi; ızgara ayrı
/// bir yer tutucu çizmez, yoksa aynı boşluk iki farklı grafikle dolardı.
class _Cell extends StatelessWidget {
  const _Cell({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => NetworkFoodImage(
    url: url,
    // Genişlik/yükseklik verildiği için `NetworkFoodImage` kendi oranını
    // uygulamaz; hücre kabından ne alırsa onu doldurur.
    width: double.infinity,
    height: double.infinity,
    radius: 0,
  );
}
