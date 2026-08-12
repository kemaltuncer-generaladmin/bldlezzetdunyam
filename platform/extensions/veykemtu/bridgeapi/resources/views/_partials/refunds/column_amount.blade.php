{{-- Tutar kuruş tutuluyor (docs/11 §0); gösterimde TL'ye çevriliyor. --}}
<span class="bld-money">{{ number_format((int) $record->amount_kurus / 100, 2, ',', '.') }} ₺</span>
