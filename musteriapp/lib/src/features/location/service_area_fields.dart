/// Adres formlarındaki il ve ilçe alanları.
///
/// Faz 1'de yalnızca Konya'nın Selçuklu ve Karatay ilçelerine teslimat
/// yapıyoruz (`ServiceArea`). Bu yüzden ikisi de serbest metin DEĞİLDİR:
/// il sabit gösterilir, ilçe iki seçenekli bir listeden gelir.
///
/// ## Neden serbest metin kaldırıldı
///
/// Serbest yazılan ilçe, hizmet vermediğimiz bir yere sipariş girilmesine
/// yol açıyordu; sipariş mutfağa düşüyor, kurye yola çıkacağı sırada iptal
/// ediliyordu. Kısıtı forma koymak, siparişi doğduktan sonra iptal etmekten
/// hem müşteri hem mutfak için ucuz.
///
/// Hem ödeme ekranı hem adres defteri AYNI parçacığı kullanır — [PinField]
/// ile aynı gerekçe: iki ayrı kopya, kural değiştiğinde birinin unutulması
/// demek.
library;

import 'package:bld_core/bld_core.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class ServiceAreaFields extends StatelessWidget {
  const ServiceAreaFields({
    super.key,
    required this.district,
    required this.onDistrictChanged,
  });

  /// Seçili ilçe; `null` ise henüz seçilmemiş.
  final String? district;

  final ValueChanged<String?> onDistrictChanged;

  /// Kayıtta hizmet alanı dışında bir ilçe varsa (kural daralmadan önce
  /// kaydedilmiş adresler) seçim boş gösterilir: listede olmayan bir değer
  /// `DropdownButtonFormField`'ı çalışma anında düşürür ve daha önemlisi,
  /// müşteri artık teslimat yapmadığımız ilçeyi seçili görmemeli.
  static String? sanitize(String? value) =>
      ServiceArea.coversDistrict(value) ? value!.trim() : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final selected = sanitize(district);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          // Adı "initial" olsa da yalnızca ilk yapımda okunmaz:
          // `DropdownButtonFormField` değer değişince seçimi de günceller.
          // Ödeme ekranında kayıtlı adres seçildiğinde ilçenin ekranda
          // değişmesi buna bağlı (`service_area_fields_test.dart`).
          initialValue: selected,
          decoration: InputDecoration(labelText: l10n.addressDistrict),
          items: [
            for (final name in ServiceArea.districts)
              DropdownMenuItem<String>(value: name, child: Text(name)),
          ],
          onChanged: onDistrictChanged,
          validator: (value) => ServiceArea.coversDistrict(value)
              ? null
              : l10n.addressDistrictRequired,
        ),
        const SizedBox(height: BldSpacing.sm),

        // İl bir alan değil, bir bilgi: değiştirilebilir gösterilseydi
        // kullanıcı deneyip reddedilirdi.
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.addressCity,
            helperText: l10n.addressServiceAreaHelp,
            enabled: false,
          ),
          child: Text(ServiceArea.city),
        ),
      ],
    );
  }
}
