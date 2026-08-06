# Kurulu Ajan Skill'leri

Bu dizindeki skill'ler **üçüncü taraf** kaynaklardan alınmıştır ve repoya kasten
commitlenmiştir: klonlayan her ajan kurulum adımı olmadan aynı tasarım
kurallarıyla çalışsın diye (üretilen `*.g.dart` dosyalarını commitleme
gerekçesiyle aynı — AGENTS.md §4).

Hepsi MIT lisanslıdır; her klasörde üst kaynağın `LICENSE` dosyası durur.

| Klasör | Üst kaynak | Ne için kullanıyoruz |
|---|---|---|
| `ui-ux-pro-max/` | [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | Renk paleti, tipografi ve stil önerileri üreten aranabilir veritabanı |
| `design-system/` | aynı repo | Üç katmanlı token mimarisi (primitive → semantic → component) |
| `ui-styling/` | aynı repo | Tailwind + shadcn/ui bileşen rehberi |
| `design-taste-frontend/` | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | Jenerik/şablon görünümlü arayüz üretmeyi engelleyen kurallar |
| `motion-design/` | [LottieFiles/motion-design-skill](https://github.com/LottieFiles/motion-design-skill) | Süre, easing, koreografi — mikro etkileşimler ve geçişler |

## Üst kaynaktan bilerek saptığımız yerler

Bu iki değişiklik güncellemede kaybolur; skill'leri yenilerken tekrar uygulayın.

1. **`ui-styling/canvas-fonts/` silindi.** 5,5 MB TTF dosyası; yalnızca skill'in
   canvas tabanlı poster üretimi için gerekli. Web arayüzü yazarken
   kullanmıyoruz, kurulumu 8 MB'tan 2,6 MB'a indirdi. Sonuç: `ui-styling`
   içindeki canvas/poster scriptleri çalışmaz, geri kalanı çalışır.

2. **`ui-ux-pro-max/SKILL.md` içindeki yollar yeniden yazıldı.** Üst kaynak
   `${CLAUDE_PLUGIN_ROOT}` değişkenine dayanıyor — bu yalnızca skill bir
   *plugin* olarak kurulduğunda tanımlıdır. Biz proje skill'i olarak kurduk,
   dolayısıyla değişken boş kalır ve script yolu bozulurdu. Yollar projeye
   göreli hale getirildi, `python` çağrıları `python3` yapıldı.

## Kullanım

Skill'ler `SKILL.md` içindeki `description` alanına göre kendiliğinden devreye
girer. `ui-ux-pro-max` ayrıca elle çağrılabilir:

```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "<sorgu>" --design-system
```

Python 3.x yeterlidir, harici bağımlılığı yoktur.
