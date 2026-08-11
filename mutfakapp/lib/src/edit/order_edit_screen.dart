/// Sipariş düzenleme ekranı — `docs/05-mutfakapp.md` §14 (K-14).
///
/// AKIŞ: personel müşteriyle **telefonda konuşur**, anlaşır, sonra
/// değişikliği buraya yazar. Ekranın en üstünde telefon ve "kaydetmeden
/// önce arayın" uyarısı duruyor — sıralamayı tersine çevirmek, müşteriye
/// haber verilmeden değişmiş bir sipariş demek.
///
/// FİYAT GÖSTERİLMEZ (ADR-08). Personel adet değiştirirken fiyata
/// bakmıyor. Para farkı yalnız **kaydetme onayında**, tek bir sayı
/// olarak çıkıyor — o da cari bakiye değil, bu düzenlemenin farkı.
///
/// TUTAR FARKINI SUNUCU HESAPLIYOR: istemci fiyat bilmediği için
/// hesaplayamaz zaten, ama bilse de hesaplamamalı — iki taraf ayrı
/// hesaplarsa hangisinin doğru olduğu tartışması çözümsüz kalır.
/// Onay penceresi bu yüzden **kaydettikten sonra** sonucu gösteriyor.
library;

import 'dart:async';

import 'package:bld_api_client/bld_api_client.dart';
import 'package:bld_core/bld_core.dart';
import 'package:bld_core/escpos.dart';
import 'package:bld_design_system/bld_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/order_edit.dart';
import '../data/providers.dart';
import '../input/onscreen_keyboard.dart';
import '../l10n/app_localizations.dart';

class OrderEditScreen extends ConsumerStatefulWidget {
  const OrderEditScreen({required this.orderId, super.key});

  final int orderId;

  static Route<bool> route(int orderId) => MaterialPageRoute<bool>(
    builder: (_) => OrderEditScreen(orderId: orderId),
  );

  @override
  ConsumerState<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends ConsumerState<OrderEditScreen> {
  /// Ekrandaki çalışma kopyası. `null` = sunucudan henüz gelmedi.
  List<EditableItem>? _items;

  /// Sunucudan gelen ilk hâl — "bir şey değişti mi" sorusunun ölçütü.
  List<EditableItem>? _original;

  RevisionReason? _reason;
  String? _customReason;
  DateTime? _requestedAt;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final order = ref.watch(editableOrderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(KdsColors.surface),
        title: Text(
          l10n.editTitle,
          style: const TextStyle(
            fontSize: KdsTextScale.columnHeader,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          tooltip: l10n.cancel,
          iconSize: 32,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: order.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(BldSpacing.xl),
              child: Text(
                l10n.editFailed(
                  error is ApiException ? error.message : '$error',
                ),
                style: const TextStyle(
                  fontSize: KdsTextScale.orderNumber,
                  color: Color(BldColors.danger),
                ),
              ),
            ),
          ),
          data: _body,
        ),
      ),
    );
  }

  Widget _body(EditableOrder order) {
    final l10n = AppL10n.of(context);

    // İlk veri geldiğinde çalışma kopyası kurulur. Sonraki yeniden
    // çizimlerde EZİLMEZ: personelin yaptığı değişiklikler kaybolurdu.
    _items ??= List<EditableItem>.of(order.items);
    _original ??= List<EditableItem>.of(order.items);
    _requestedAt ??= order.requestedAt;

    final items = _items!;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(BldSpacing.lg),
            children: [
              _ContactCard(order: order),
              if (order.isSubscription) ...[
                const SizedBox(height: BldSpacing.md),
                _WarningBox(text: l10n.editSubscriptionWarning),
              ],
              const SizedBox(height: BldSpacing.lg),
              _SectionTitle(text: l10n.editItems),
              if (items.isEmpty)
                _WarningBox(text: l10n.editEmptyItems)
              else
                for (var index = 0; index < items.length; index++)
                  _ItemRow(
                    item: items[index],
                    onChanged: (quantity) => setState(() {
                      // ADET 0 = KALEMİ KALDIR. Ayrı bir "kaldır"
                      // düğmesi de var ama eksiye basa basa sıfıra
                      // inen personelin beklentisi kalkması.
                      if (quantity <= 0) {
                        items.removeAt(index);
                      } else {
                        items[index] = items[index].copyWith(
                          quantity: quantity,
                        );
                      }
                    }),
                    onRemove: () => setState(() => items.removeAt(index)),
                  ),
              const SizedBox(height: BldSpacing.md),
              FilledButton.tonalIcon(
                onPressed: () => unawaited(_addProduct()),
                icon: const Icon(Icons.add),
                label: Text(l10n.editAddProduct),
              ),
              const SizedBox(height: BldSpacing.lg),
              _SectionTitle(text: l10n.editReason),
              _ReasonPicker(
                selected: _reason,
                customReason: _customReason,
                onSelected: (reason, custom) => setState(() {
                  _reason = reason;
                  _customReason = custom;
                }),
              ),
            ],
          ),
        ),
        _SaveBar(
          enabled: !_saving && items.isNotEmpty && _changed,
          saving: _saving,
          onSave: () => unawaited(_save(order)),
        ),
      ],
    );
  }

  /// Kaydedilecek bir şey var mı?
  ///
  /// Değişiklik yokken kaydetmek boş bir revizyon üretir ve fişleri
  /// gereksiz yere yeniden bastırır — mutfakta kâğıt para demek.
  bool get _changed {
    final original = _original;
    final items = _items;
    if (original == null || items == null) return false;

    if (original.length != items.length) return true;

    for (var i = 0; i < items.length; i++) {
      if (items[i] != original[i]) return true;
    }

    return false;
  }

  String? get _reasonText => switch (_reason) {
    null => null,
    RevisionReason.other => _customReason,
    final reason => reason.label,
  };

  Future<void> _addProduct() async {
    final selected = await showModalBottomSheet<({int menuId, String name})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(KdsColors.surface),
      builder: (context) => const _ProductPicker(),
    );

    if (selected == null || !mounted) return;

    setState(() {
      final items = _items!;
      final existing = items.indexWhere((i) => i.menuId == selected.menuId);

      // AYNI ÜRÜN İKİNCİ KEZ EKLENİRSE adet artar, ikinci satır açılmaz:
      // iki ayrı satır fişte de iki ayrı satır olur ve mutfak aynı
      // yemeği iki kez hazırlar.
      if (existing >= 0) {
        items[existing] = items[existing].copyWith(
          quantity: items[existing].quantity + 1,
        );
      } else {
        items.add(
          EditableItem(menuId: selected.menuId, name: selected.name, quantity: 1),
        );
      }
    });
  }

  Future<void> _save(EditableOrder order) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final reason = _reasonText;
    if (reason == null || reason.trim().isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.warning),
          content: Text(
            l10n.editReasonRequired,
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(BldColors.neutral900),
            ),
          ),
        ),
      );
      return;
    }

    if (!await _confirm(order)) return;

    setState(() => _saving = true);

    try {
      final result = await ref
          .read(orderEditApiProvider)
          .createRevision(
            orderId: widget.orderId,
            reason: reason,
            items: _items!,
            requestedAt: _requestedAt == order.requestedAt ? null : _requestedAt,
          );

      // Panonun revizyonu hemen görmesi için kaynak tazeleniyor;
      // beklemek, fişlerin bir yoklama turu geç tetiklenmesi demekti.
      await ref.read(orderSourceProvider).refresh();

      // TEK BİLDİRİM, İKİ DEĞİL. Önce "kaydedildi" sonra "iade
      // başlatılamadı" göstermek, ikisini kuyruğa sokar: personel ilkini
      // görüp gider, ikincisi kimseye ulaşmaz. Para uyarısı varsa
      // başarı mesajının YERİNE geçer ve daha uzun durur.
      final warning = _settlementWarning(l10n, result);

      messenger.showSnackBar(
        SnackBar(
          duration: Duration(seconds: warning == null ? 4 : 10),
          backgroundColor: Color(
            warning == null ? BldColors.success : BldColors.warning,
          ),
          content: Text(
            warning ?? _savedMessage(l10n, result),
            style: const TextStyle(
              fontSize: KdsTextScale.statusBar,
              color: Color(BldColors.neutral900),
            ),
          ),
        ),
      );

      navigator.pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(BldColors.danger),
          content: Text(
            l10n.editFailed(error is ApiException ? error.message : '$error'),
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
        ),
      );
    }
  }

  /// Kaydedildi mesajı — para farkı çıktıysa TUTARIYLA birlikte.
  ///
  /// NEDEN TUTAR BURADA GÖSTERİLİYOR, ONAY DİYALOĞUNDA DEĞİL: personel bu
  /// değişikliği müşteriyle telefonda konuşup anlaşarak giriyor ve
  /// "ne kadarı iade edildi" sorusunun cevabını kapatmadan önce görmesi
  /// gerekiyor. Kaydetmeden ÖNCE gösterilemiyor çünkü fiyatı istemci
  /// bilmiyor (ADR-08); sunucu farkı ancak kayıtla birlikte döndürüyor.
  ///
  /// GÖSTERİLEN YALNIZCA FARK, cari bakiye değil — ADR-08 korunuyor.
  String _savedMessage(AppL10n l10n, RevisionResult result) {
    final saved = l10n.editSaved(result.revisionNo);

    if (result.refundKurus > 0) {
      return '$saved — ${l10n.editRefund(Money.format(result.refundKurus))}';
    }
    if (result.extraChargeKurus > 0) {
      return '$saved — '
          '${l10n.editExtraCharge(Money.format(result.extraChargeKurus))}';
    }

    return saved;
  }

  /// Para farkı kendiliğinden kapanmadıysa personele söylenecek uyarı.
  ///
  /// SESSİZ GEÇİLMEZ: "iade elle yapılacak" ya da "iade başlatılamadı"
  /// bilgisi kimseye ulaşmazsa müşteri parasını bekler ve kimse bir şey
  /// bilmez. Uyarı, başarı mesajının **yerine** gösteriliyor — arka arkaya
  /// iki bildirim kuyruğa girer ve ikincisi görülmez.
  String? _settlementWarning(AppL10n l10n, RevisionResult result) =>
      switch (result.settlementStatus) {
        'manual' => l10n.editSettlementManual(result.settlementMessage ?? ''),
        'failed' => l10n.editSettlementFailed,
        _ => null,
      };

  /// Kaydetmeden önceki son onay.
  ///
  /// TUTAR BURADA GÖSTERİLMİYOR: fiyatı istemci bilmiyor (ADR-08) ve
  /// sunucudan "ne kadar olurdu" diye sormak, kaydetmeden önce ikinci
  /// bir uç ve ikinci bir hesap demekti. Onay, **ne değiştiğini**
  /// gösteriyor; para sonucu kaydettikten sonra bildiriliyor.
  Future<bool> _confirm(EditableOrder order) async {
    final l10n = AppL10n.of(context);
    final changes = _changeSummary(order);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(KdsColors.surface),
        title: Text(l10n.editConfirmTitle),
        content: SizedBox(
          width: 640,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final change in changes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• $change',
                    style: const TextStyle(fontSize: KdsTextScale.orderNumber),
                  ),
                ),
              const SizedBox(height: BldSpacing.md),
              Text(
                '${l10n.editReason}: ${_reasonText ?? ''}',
                style: const TextStyle(
                  fontSize: KdsTextScale.statusBar,
                  color: Color(KdsColors.onSurfaceMuted),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.editSave),
          ),
        ],
      ),
    );

    return ok ?? false;
  }

  /// İnsan okuyabilir değişiklik listesi.
  ///
  /// Sunucu da aynı özeti üretiyor (`OrderEditor::summaryLines`) ve fişe
  /// o basılıyor. Buradaki kopya yalnız **onay öncesi** gösterim için;
  /// kaydedilen metin sunucununkidir.
  List<String> _changeSummary(EditableOrder order) {
    final before = {for (final item in order.items) item.menuId: item};
    final after = {for (final item in _items!) item.menuId: item};

    final lines = <String>[];
    for (final menuId in {...before.keys, ...after.keys}) {
      final from = before[menuId];
      final to = after[menuId];

      if (from == null && to != null) {
        lines.add('EKLENDİ: ${to.name} ×${to.quantity}');
      } else if (to == null && from != null) {
        lines.add('ÇIKARILDI: ${from.name} ×${from.quantity}');
      } else if (from != null && to != null && from.quantity != to.quantity) {
        lines.add('${to.name}: ${from.quantity} → ${to.quantity}');
      }
    }

    return lines;
  }
}

/// Müşteri bilgisi ve "önce arayın" uyarısı.
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.order});

  final EditableOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Material(
      color: const Color(KdsColors.surface),
      borderRadius: BorderRadius.circular(BldRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.orderNumber,
              style: const TextStyle(
                fontSize: KdsTextScale.columnHeader,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (order.customerName != null)
              Text(
                order.customerName!,
                style: const TextStyle(fontSize: KdsTextScale.orderNumber),
              ),
            if (order.customerPhone != null) ...[
              const SizedBox(height: BldSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.phone_in_talk_outlined,
                    size: 30,
                    color: Color(BldColors.brand400),
                  ),
                  const SizedBox(width: BldSpacing.sm),
                  SelectableText(
                    order.customerPhone!,
                    style: const TextStyle(
                      fontSize: KdsTextScale.columnHeader,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: BldSpacing.sm),
            Text(
              l10n.editPhoneHint,
              style: const TextStyle(
                fontSize: KdsTextScale.statusBar,
                fontWeight: FontWeight.bold,
                color: Color(BldColors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek kalem satırı: büyük − / adet / + ve kaldır.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final EditableItem item;
  final void Function(int quantity) onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BldSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: KdsTextScale.itemName),
                ),
                if (item.options.isNotEmpty)
                  Text(
                    '(${item.options.join(', ')})',
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: Color(KdsColors.onSurfaceMuted),
                    ),
                  ),
                if (item.note != null)
                  Text(
                    item.note!,
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: Color(KdsColors.noteForeground),
                    ),
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: l10n.settingsDecrease,
            iconSize: 30,
            onPressed: () => onChanged(item.quantity - 1),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 90,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: KdsTextScale.quantity,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: l10n.settingsIncrease,
            iconSize: 30,
            onPressed: () => onChanged(item.quantity + 1),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: BldSpacing.sm),
          IconButton(
            tooltip: l10n.editRemove,
            iconSize: 28,
            color: const Color(BldColors.danger),
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

/// Sebep seçimi. "Diğer" seçilince ekran klavyeli metin alanı açılır.
class _ReasonPicker extends StatelessWidget {
  const _ReasonPicker({
    required this.selected,
    required this.customReason,
    required this.onSelected,
  });

  final RevisionReason? selected;
  final String? customReason;
  final void Function(RevisionReason reason, String? custom) onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: BldSpacing.sm,
    runSpacing: BldSpacing.sm,
    children: [
      for (final reason in RevisionReason.values)
        ChoiceChip(
          selected: selected == reason,
          label: Text(
            reason == RevisionReason.other && customReason != null
                ? customReason!
                : reason.label,
            style: const TextStyle(fontSize: KdsTextScale.statusBar),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: BldSpacing.md,
            vertical: BldSpacing.sm,
          ),
          onSelected: (_) async {
            if (reason != RevisionReason.other) {
              onSelected(reason, null);
              return;
            }

            final text = await _promptCustomReason(context);
            if (text != null) onSelected(reason, text);
          },
        ),
    ],
  );
}

Future<String?> _promptCustomReason(BuildContext context) async {
  final controller = TextEditingController();

  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(KdsColors.surface),
      title: Text(AppL10n.of(context).editReason),
      content: SizedBox(
        width: 900,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 160,
                style: const TextStyle(fontSize: KdsTextScale.orderNumber),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: BldSpacing.md),
              OnscreenKeyboard(
                controller: controller,
                onSubmit: () => Navigator.of(context).pop(controller.text),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppL10n.of(context).cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(AppL10n.of(context).save),
        ),
      ],
    ),
  );

  controller.dispose();

  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Ürün ekleme alt sayfası — aranabilir, **fiyatsız**.
class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker();

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final menu = ref.watch(kitchenAddableMenuProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: KdsTextScale.orderNumber),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n.editProductSearch,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: BldSpacing.md),
            SizedBox(
              height: 420,
              child: menu.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    l10n.editFailed(
                      error is ApiException ? error.message : '$error',
                    ),
                    style: const TextStyle(
                      fontSize: KdsTextScale.statusBar,
                      color: Color(BldColors.danger),
                    ),
                  ),
                ),
                data: (items) {
                  final query = TurkishCase.toLowerCase(_search.text.trim());
                  final filtered = query.isEmpty
                      ? items
                      : items
                            .where(
                              (item) => TurkishCase.toLowerCase(
                                item.name,
                              ).contains(query),
                            )
                            .toList(growable: false);

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: BldSpacing.md,
                        vertical: BldSpacing.sm,
                      ),
                      title: Text(
                        filtered[index].name,
                        style: const TextStyle(
                          fontSize: KdsTextScale.orderNumber,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(filtered[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BldSpacing.sm),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: KdsTextScale.columnHeader,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(BldSpacing.md),
    decoration: BoxDecoration(
      color: const Color(KdsColors.noteBackground),
      borderRadius: BorderRadius.circular(BldRadius.sm),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: KdsTextScale.statusBar,
        fontWeight: FontWeight.bold,
        color: Color(KdsColors.noteForeground),
      ),
    ),
  );
}

/// Alt çubuk — tek büyük kaydet düğmesi.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.enabled,
    required this.saving,
    required this.onSave,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Material(
      color: const Color(KdsColors.surface),
      child: Padding(
        padding: const EdgeInsets.all(BldSpacing.lg),
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(76)),
          onPressed: enabled ? onSave : null,
          child: saving
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : Text(enabled ? l10n.editSave : l10n.editNoChange),
        ),
      ),
    );
  }
}
