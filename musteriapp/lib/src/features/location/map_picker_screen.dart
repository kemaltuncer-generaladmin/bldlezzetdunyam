/// Haritadan teslimat noktası seçme.
///
/// NEDEN VAR: serbest metin adres kuryeyi kapıya götürmüyor. Aynı ilçede
/// birden fazla "Atatürk Cad. No:12" olabiliyor; sokak tabelası olmayan
/// şantiye ve site teslimatlarında adres tek başına yetersiz kalıyor.
///
/// ## İğne SABİT, harita HAREKETLİ
///
/// İğne ekranın ortasına çivilenmiştir; kullanıcı haritayı altında kaydırır.
/// Sürüklenebilir işaretçi denenmedi çünkü parmağın altında kalan iğne tam
/// bırakılacağı anda görünmez oluyor ve kullanıcı noktayı göremeden bırakıyor.
/// Sabit iğnede hedef her an açıkta.
///
/// ## Koordinat İSTEĞE BAĞLI
///
/// Ekran "iptal" ile kapanabilir ve iğne hiç seçilmeyebilir. Konum izni
/// vermeyen ya da haritayı kullanmak istemeyen müşteri adresi elle yazıp
/// sipariş verebilmeli — harita bir kolaylık, kapı değil.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:bld_design_system/bld_design_system.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/bld_theme.dart';

/// Ekranın döndürdüğü sonuç.
///
/// `null` dönüş "vazgeçildi, hiçbir şey değişmesin" demektir. İğnenin
/// KALDIRILMASI ise ayrı bir durumdur ve [MapPickerResult.cleared] ile
/// bildirilir — ikisi aynı değere indirgenirse "iğneyi kaldır" düğmesi
/// sessizce iptal gibi davranır ve eski koordinat kayıtta kalır.
@immutable
class MapPickerResult {
  const MapPickerResult.picked(LatLng this.point) : cleared = false;

  const MapPickerResult.cleared() : point = null, cleared = true;

  final LatLng? point;
  final bool cleared;
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initial});

  /// Varsa mevcut iğne; harita buradan açılır.
  final LatLng? initial;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  /// Bursa merkez — firmanın hizmet verdiği il.
  ///
  /// İğnesiz açılışta bir yerden başlamak gerekiyor ve o yer boş okyanus
  /// (0,0) olmamalı: kullanıcı haritayı kıtalar boyunca kaydırmak zorunda
  /// kalırdı. Konum izni Faz 2'de eklendiğinde burası cihazın konumuyla
  /// değişir (`docs/11-yol-haritasi.md`).
  static const LatLng _fallback = LatLng(40.1885, 29.0610);

  /// Şehir ölçeğinde açılır: sokaklar okunur, ama kullanıcı hangi mahallede
  /// olduğunu da görür. İğne varsa daha yakından bakılır.
  static const double _cityZoom = 13;

  static const double _pinZoom = 17;

  late final MapController _controller = MapController();

  /// Haritanın o anki merkezi — iğne burada duruyor.
  late LatLng _center = widget.initial ?? _fallback;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    // Her karede setState çağırmıyoruz: yalnızca hareket bittiğinde
    // güncelleniyor. Kaydırma sırasında saniyede altmış kez yeniden çizmek
    // düşük donanımlı telefonlarda haritayı takılmalı gösteriyordu.
    if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      setState(() => _center = event.camera.center);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapPickerTitle),
        actions: [
          if (widget.initial != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(const MapPickerResult.cleared()),
              child: Text(
                l10n.mapPickerClear,
                style: TextStyle(color: bldColor(BldColors.neutral0)),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial != null ? _pinZoom : _cityZoom,
              onMapEvent: _onMapEvent,
              // Döndürme kapalı: kuzeyi kaybeden kullanıcı haritada
              // yönünü bulamıyor ve iki parmakla yanlışlıkla döndürmek çok
              // kolay. Teslimat noktası seçmek için döndürmeye gerek yok.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // OSM kullanım koşulu: istemci kendini tanıtmak zorunda.
                // Boş bırakılırsa karolar bir süre sonra engellenir.
                userAgentPackageName: 'tr.com.benimlezzetdunyam.musteriapp',
                maxZoom: 19,
              ),
            ],
          ),

          // Sabit iğne. `IgnorePointer`: iğne haritanın dokunmalarını
          // yutmamalı, altındaki harita kaydırılabilir kalmalı.
          IgnorePointer(
            child: Center(
              // Yarım iğne boyu yukarı: ikonun SİVRİ UCU ekranın tam
              // ortasına, yani seçilen koordinata denk gelsin. Ortalanmış
              // bırakılsaydı seçilen nokta iğnenin gövdesinin ortası olur
              // ve kullanıcı gördüğü yerden ~20 m sapardı.
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Icon(
                  Icons.location_on,
                  size: 40,
                  color: bldColor(BldColors.brand600),
                  shadows: const [
                    Shadow(blurRadius: 6, color: Colors.black38),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Panel(center: _center),
          ),
        ],
      ),
    );
  }
}

/// Alt bilgi ve onay şeridi.
class _Panel extends StatelessWidget {
  const _Panel({required this.center});

  final LatLng center;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: bldColor(BldColors.neutral0),
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(BldSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.mapPickerHint, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: BldSpacing.xs),

              // Kaynak gösterimi OSM lisansının GEREĞİ, süs değil.
              Text(
                l10n.mapPickerAttribution,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: BldSpacing.md),

              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(MapPickerResult.picked(center)),
                child: Text(l10n.mapPickerConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
