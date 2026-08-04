/// Zorunlu güncelleme mantığı — `docs/07-musteriapp.md` §2, §7.
///
/// Saf fonksiyonlar; ağ, Flutter veya Riverpod bilmez, bu yüzden doğrudan test
/// edilir.
library;

/// `docs/openapi.yaml` `SemVer`: `^\d+\.\d+\.\d+$`.
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final RegExp _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

  /// Sözleşmeye uymayan girdide `null`. Atmak yerine `null` dönmek bilinçli:
  /// çağıran, ayrıştıramadığı bir sürüm yüzünden kullanıcıyı kilitlememelidir.
  static SemanticVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) return null;

    return SemanticVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// Yüklü sürüm `min_supported` altındaysa engelleyici ekran gösterilir.
///
/// **Eşit sürüm engellenmez** — `min_supported` "desteklenen en düşük sürüm"
/// demektir, "bunun üstünde ol" demek değildir.
///
/// Taraflardan biri ayrıştırılamazsa `false` döner: bozuk bir sunucu yanıtı
/// yüzünden uygulamayı kilitlemek, güncel olmayan bir istemciyi çalıştırmaktan
/// daha kötüdür.
bool isUpdateRequired({required String current, required String minSupported}) {
  final installed = SemanticVersion.tryParse(current);
  final minimum = SemanticVersion.tryParse(minSupported);
  if (installed == null || minimum == null) return false;

  return installed < minimum;
}
