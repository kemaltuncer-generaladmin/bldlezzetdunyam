#!/usr/bin/env python3
"""KDS uyarı seslerini üretir — `assets/sounds/` altındaki .wav dosyaları.

NEDEN ÜRETİCİ BETİK, NEDEN İNDİRİLMİŞ SES: mutfağa giden her sesin ne
olduğu, ne kadar sürdüğü ve neden diğerlerinden ayırt edilebilir olduğu
kayıtlı olmalı. Bir yerden indirilmiş .wav dosyası bunların hiçbirini
söylemez, lisansı da belirsizdir. Buradaki sesler saf ton sentezidir:
telifsiz, yeniden üretilebilir, ve ayırt edilebilirlikleri gerekçeli.

AYIRT EDİLEBİLİRLİK KURALI (`docs/05` §5.5): ocak başındaki kişi ekrana
bakmadan hangi olayın olduğunu anlamalı. Bu yüzden her ses farklı bir
BOYUTTA ayrışır — yalnız perde değil; ritim, tını ve yön de farklı:

    yeni_siparis    (elde)  ısrarcı, tekrar eden
    baglanti_yok    (elde)  alçalan iki ton, aralıklı
    gecikme         sert, YÜKSELEN üç kısa bip     → "acele et"
    yazici_hatasi   alçak, titreşimli iki vuruş    → "makine sorunu"
    abonelik        yumuşak çan, majör üçlü        → "bilgi, acil değil"
    bbd_siparis     dört notalı motif, marimba     → "başka kanaldan sipariş"

Çalıştırma:  python3 tool/ses_uret.py
Biçim: 48 kHz, 16-bit, mono — `baglanti_yok.wav` ile aynı (pw-play/aplay
yeniden örneklemesin diye kasadaki varsayılan hızla eşleşiyor).
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

RATE = 48_000
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def write(name: str, samples: list[float]) -> None:
    """Örnekleri 16-bit mono WAV olarak yazar (kırpma korumalı)."""
    peak = max((abs(s) for s in samples), default=1.0) or 1.0
    scale = 0.89 / peak  # tepe %89: ucuz hoparlörler %100'de cızırdıyor

    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767))
        for s in samples
    )

    path = OUT / name
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)

    print(f"{name}: {len(samples) / RATE:.2f} sn, {path.stat().st_size} bayt")


def silence(seconds: float) -> list[float]:
    return [0.0] * int(RATE * seconds)


def tone(
    freq: float,
    seconds: float,
    *,
    harmonics: tuple[float, ...] = (1.0,),
    decay: float | None = None,
    tremolo: float = 0.0,
    fade: float = 0.006,
) -> list[float]:
    """Tek bir nota.

    `harmonics` üst harmoniklerin genlikleri (tını); `decay` verilirse
    üstel sönüm (çan/marimba), verilmezse düz zarf. `fade` başta ve sonda
    kısa yumuşatma — olmazsa hoparlörden "tık" sesi çıkar.
    """
    total = int(RATE * seconds)
    fade_n = max(1, int(RATE * fade))
    out: list[float] = []

    for i in range(total):
        t = i / RATE
        value = sum(
            amp * math.sin(2 * math.pi * freq * (n + 1) * t)
            for n, amp in enumerate(harmonics)
        )

        if decay is not None:
            value *= math.exp(-t / decay)

        if tremolo:
            value *= 0.55 + 0.45 * math.sin(2 * math.pi * tremolo * t)

        if i < fade_n:
            value *= i / fade_n
        elif i > total - fade_n:
            value *= (total - i) / fade_n

        out.append(value)

    return out


def gecikme() -> list[float]:
    """Yükselen üç kısa bip — "sipariş bekliyor, acele et"."""
    out: list[float] = []
    for freq in (880.0, 1046.5, 1318.5):
        # Tek sayılı harmonikler: kare dalgaya yakın, sert ve delici.
        out += tone(freq, 0.11, harmonics=(1.0, 0.0, 0.34, 0.0, 0.18))
        out += silence(0.06)

    return out


def yazici_hatasi() -> list[float]:
    """Alçak, titreşimli iki vuruş — takılmış motor çağrışımı."""
    out: list[float] = []
    for _ in range(2):
        out += tone(196.0, 0.30, harmonics=(1.0, 0.45, 0.22), tremolo=22.0)
        out += silence(0.10)

    return out


def abonelik() -> list[float]:
    """Yumuşak çan, majör üçlü — bilgi verir, telaş yaratmaz."""
    out: list[float] = []
    for freq in (523.25, 659.25, 783.99):
        out += tone(freq, 0.42, harmonics=(1.0, 0.30, 0.12), decay=0.28)

    # Son akor birlikte: kapanış hissi.
    chord = [0.0] * int(RATE * 0.55)
    for freq in (523.25, 659.25, 783.99):
        for i, s in enumerate(tone(freq, 0.55, harmonics=(1.0, 0.25), decay=0.24)):
            chord[i] += s / 3

    return out + chord


def bbd_siparis() -> list[float]:
    """Dört notalı motif — yeni sipariş sesiyle karışmaması şart.

    BBD siparişleri BLD panosuna hiç girmez (K-16); personel bu sesi
    duyduğunda ekrana değil YAZICIYA bakmalı. Bu yüzden hem ritmi hem
    yönü yeni sipariş sesinden farklı: kısa-kısa-uzun, aşağı-yukarı.
    """
    out: list[float] = []
    for freq, dur in ((783.99, 0.13), (587.33, 0.13), (659.25, 0.13), (880.0, 0.40)):
        out += tone(freq, dur, harmonics=(1.0, 0.42, 0.16), decay=0.16)
        out += silence(0.035)

    return out


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)

    write("gecikme.wav", gecikme())
    write("yazici_hatasi.wav", yazici_hatasi())
    write("abonelik.wav", abonelik())
    write("bbd_siparis.wav", bbd_siparis())
