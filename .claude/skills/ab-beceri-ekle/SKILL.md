---
name: ab-beceri-ekle
description: Ashen Bastion'a aktif beceri, pasif veya evrim eklerken (data/skills JSON, davranış sınıfı, SkillRegistry, ikon, ses, kabul tabloları) kullan.
---

# Beceri / pasif / evrim ekle

Başlamadan: kb kartının `## Çalışma notları` bölümünü oku; kapı `bash tools/gate.sh`.

## Adımlar
1. **Sözleşme önce:** `data/skills/<id>.json` + `scripts/sim/skills/<id>.gd` (no-op) + `SkillRegistry.BEHAVIORS` satırı (alfabetik; `scripts/sim/skills/skill_registry.gd`). Paralel fazlar aynı kayıt dosyalarına yazacaksa sözleşme fazı bunları önceden hazırlar.
2. **Şema:** `docs/data-schema.md` becerilerin bölümü: `max_level` 1..8 (evrimde 1), `levels`/`desc` uzunluğu = `max_level`, aktif monotonluk, pasif `levels[i]` TOPLAM. Örnekler: `data/skills/hortum.json` (aktif), `tufan.json` (evrim), `hizli_parmak.json` (pasif + `variants.zyfen`).
3. **Havuz:** `pool: "common"` ya da karakter kimliği; `variants` yalnız `common`'da; evrim havuzu = `requires.active` havuzu.
4. **Davranış:** `docs/dev/skill-hooks.md` (kanca imzaları değişmez, sona eklenir; `test/` altındaki `test_contract_hooks.gd` makine okunur denetler). Rastgelelik yalnız `rng_combat`.
5. **İkon:** `ab-gorsel-ikon-uret`; **ses:** `ab-ses-ekle` (`cast_sfx`); **efekt:** `ab-efekt-shader`.
6. **Testler:** birim `test/unit/test_v202_wind_basic.gd`, `test_v202_wind_evo.gd` kalıbı; kabul tabloları `test/helpers/expected_tables_v202.gd`; sayı değişirse test itirazı turu; yeni test dosyası → `ab-test-ve-kapi`.
7. **Fuzz/ölçüm:** `test/helpers/fuzz_invariants.gd`, `tools/balance/mid_run.gd` `PRIORITY`.
8. **DPS bandı:** `tools/balance/dps_density.gd` (evrim ÷ aktif 1,8–2,2) → `ab-denge-olcumu`.

## Dokunulan dosyalar
`data/skills/<id>.json`, `scripts/sim/skills/<id>.gd`, `scripts/sim/skills/skill_registry.gd`, `scripts/sim/skill_def.gd`, `scripts/sim/data_v2.gd`, `docs/data-schema.md`, `docs/dev/skill-hooks.md`, `docs/design/v2.0.2/behavior-contract.md`, `test/helpers/expected_tables_v202.gd`, `tools/gate_min_tests.json`, `assets/ui/icons/`.

## Doğrulama
`bash tools/gate.sh` (adım 4 veri doğrulama), GUT, altın hash'ler (`test/fixtures/golden_hashes.json`; sim değiştiyse yalnız ilgili karakter kaydı), `ab-denge-olcumu`.

## Kontrol listesi
- [ ] Bilinen açığı sabitleyen test `karakterizasyon (F-xxx)` adıyla; düzeltme fazı testi ters çevirir.
- [ ] Kabul testi kusurlu davranışı beklenen değer yapmaz; bulgu kimliğine bağlı `pending`.
- [ ] Global/önbellek (GameData, ayar) durumuna yazan test `after_each` ile geri alır (sızıntı = kırmızı gate).
- [ ] Ortak kayıt dosyaları (`tools/gate_min_tests.json`, `SkillRegistry`) çakışmasız; rapordan önce entegrasyon dalı alınır.
- [ ] Harita/çarpışma/hareket etkisi varsa test botları (`test/helpers/bots.gd`) ve kısa koşu testleri aynı fazda.
- [ ] Altın hash: Gunslinger kayıtları değişmedi (değiştiyse neden).

## Örnek
Zyfen rüzgâr kesiği: `data/skills/ruzgar_kesigi.json` + `scripts/sim/skills/ruzgar_kesigi.gd`; evrimi `tufan` (`requires.active`).
