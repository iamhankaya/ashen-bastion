# Ana sayfa sahne dokuları (v2.0.3 D)

Yeni görsel ÜRETİLMEDİ (Codex/Gemini kullanılmadı). Dokular `docs/design/v2.0.3/mock/assets/` türevleridir; onlar da
`art/ref/harita/harabe-parcalari.png` + `zemin-doku.png` ve `docs/ui/mockups/assets/gunslinger-atis-keyed.png`
dosyalarının yeşil perdesi silinmiş / kenarı eritilmiş kırpmalarıdır (`docs/design/v2.0.3/mock/make_assets.py`).

| Dosya (`assets/gfx/ui/menu/`) | Kaynak | Not |
|---|---|---|
| `kemer.png`, `kule.png`, `sur.png`, `sancak1.png`, `sancak2.png`, `mesale.png` | `harabe-parcalari.png` kırpması | uzak sahne; parlaklık kodda (modulate) |
| `zemin-yama.png` | `zemin-doku.png` | kenar yumuşatma kodda (shader maskesi) |
| `karakter.png` | Gunslinger atış görseli (`ana_gorsel` türevi) | yatay 56 px alfa eritme; namlu alevi kenarda kesilmez |

UI yüzeyleri (`assets/ui/v203/*.svg`): `docs/design/v2.0.3/frames/` içinden birebir kopya (elle yazılmış SVG, tasarım turu).
Eski `assets/gfx/ui/ana_gorsel.png` artık menüde kullanılmıyor (başka kullanıcısı yok; silinmedi, temizlik ayrı iş).
Tarih: 2026-10-26.
