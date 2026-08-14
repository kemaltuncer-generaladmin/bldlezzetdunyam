/// Adres formlarında haritayı açan alan.
///
/// Hem sepet ekranında hem adres defterinde AYNI parçacık kullanılıyor. İki
/// yere ayrı ayrı yazılsaydı, biri iğneyi siparişe taşırken diğerinin
/// unutması an meselesiydi; koordinatın yarısının kaybolduğu kusurlar tam
/// olarak böyle doğuyor.
library;

import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/bld_theme.dart';
import 'map_picker_screen.dart';

class PinField extends StatelessWidget {
  const PinField({super.key, required this.point, required this.onChanged});

  /// Seçili nokta; `null` ise iğne yok.
  final LatLng? point;

  /// Yeni nokta ya da iğne kaldırıldığında `null`.
  final ValueChanged<LatLng?> onChanged;

  Future<void> _open(BuildContext context) async {
    final result = await Navigator.of(context).push<MapPickerResult>(
      MaterialPageRoute(builder: (_) => MapPickerScreen(initial: point)),
    );

    // `null` = geri tuşu. Hiçbir şey değişmemeli; iğneyi kaldırmak AYRI bir
    // sonuç. İkisi aynı sayılsaydı ekrandan geri çıkan kullanıcı iğnesini
    // farkında olmadan silerdi.
    if (result == null) return;

    onChanged(result.cleared ? null : result.point);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = point != null;

    return Container(
      padding: const EdgeInsets.all(BldSpacing.sm),
      decoration: BoxDecoration(
        color: selected
            ? bldColor(BldColors.brand50)
            : bldColor(BldColors.neutral50),
        borderRadius: BorderRadius.circular(BldRadius.sm),
        border: Border.all(
          color: selected
              ? bldColor(BldColors.brand200)
              : bldColor(BldColors.neutral200),
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.location_on_outlined : Icons.location_off_outlined,
            color: selected
                ? bldColor(BldColors.brand600)
                : bldColor(BldColors.neutral400),
          ),
          const SizedBox(width: BldSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected ? l10n.mapPickerSelected : l10n.mapPickerNotSelected,
                  style: theme.textTheme.titleMedium,
                ),
                Text(l10n.mapPickerOptional, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _open(context),
            child: Text(selected ? l10n.mapPickerChange : l10n.mapPickerSelect),
          ),
        ],
      ),
    );
  }
}
