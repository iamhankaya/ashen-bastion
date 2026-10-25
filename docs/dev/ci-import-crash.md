# F-042: Godot `--headless --import` aralıklı çöküşü

**Belirti.** CI `selftest (1)` (ve seyrek gate "2. İçe aktarma"): `tools/gate.sh: line 40: Aborted (core dumped)`, ~26 sn sonra,
test gövdesine gelmeden. Örnekler: PR #69 (run 40176568897, job 121118409267), PR #70 (run 40177379913, job 121120913238), ikisi
de `taban_yesil` (aynı işin 3. temiz kopya içe aktarması; önceki iki senaryo aynı işte sorunsuz geçti).

**Kök neden: kanıtlanamadı.** Yerelde Godot 4.7.2 ile temiz kopyada **21 içe aktarma** (6 art arda + 3×5 paralel) çökmedi;
`.gate/import.log` CI'dan alınamadı (artifact yok), core dump CI'da kalıyor. Şu an tetikleyici kaynak (shader / büyük PNG / `.import`)
ayrıştırılamadı. Çöküş içe aktarmanın ortasında (SIGABRT) olduğu ve temiz önbellekte aralıklı olduğu için en olası sınıf Godot'nun
kendi eşzamanlı içe aktarma yarışıdır; bu **varsayımdır**. Kanıt toplamak için aşağıdaki yeniden deneme çöküşü loglar.

**Önlem (belgeli, sınırlı).** `tools/ci/godot_import.sh` (gate adım 2):
- İmza = kabuk çıkış kodu **134** (SIGABRT) **ve** günlükte `^SCRIPT ERROR|Parse Error|ERROR:` yok. Yalnız bu en çok **1 kez** yeniden denenir
  (yarım `.godot` silinerek). SIGKILL/OOM (137), normal hata (1) ve içerik hatalı 134 yeniden denenmez.
- Her deneme stderr'e, `.gate/import_retry.txt`'ye, `$GITHUB_STEP_SUMMARY`'ye (`IMPORT_RETRY: ...`, son günlük satırı dahil) yazılır;
  ilk çöküş günlüğü `.gate/import.log.deneme1`. Gate sonunda "İçe aktarma yeniden denemesi" bölümü basılır.
- **İkinci çöküş gate'i kırmızı bırakır** (çıkış 134). Sessiz yeniden deneme yok.
- `IMPORT_RETRY` satırı görülen her CI koşusu F-042 verisidir: tekrar sıklığı ölçülmeli; ikinci çöküş görülürse önlem yetersiz demektir.

**Önbellek.** CI yalnız Godot ikilisini önbelleğe alır (`~/.cache/ashen-bastion`, anahtar `godot-<hashFiles('.godot-version')>`;
sürüm + `checksums.txt` SHA-512 doğrulaması `ensure_godot.sh`'te). `.godot/` içe aktarma önbelleği CI'da **önbelleğe alınmıyor**, her koşu
temiz içe aktarır; anahtar sorunu yok. Yerelde bozuk `.godot`: `--import` çıkış 0 verir, yalnız `ERROR:` yazar (gate "günlükte hata
satırı" ile kırmızı) ve sıfırlanmış `.ctex` dosyalarını yeniden üretmez; çözüm `rm -rf .godot`. Prova: `bash tools/ci/prova_import_cache.sh`.
Testler: `tools/ci/tests/test_godot_import.py`.

**Kanıt toplama (sonraki gerçek çöküş için).** `ci.yml` `test` ve `selftest` işleri `ASHEN_EVIDENCE_DIR=$RUNNER_TEMP/import-evidence` ayarlar;
`godot_import.sh` `ulimit -c unlimited` koyar ve her çöküşte (yeniden deneme sonunda iş yeşil olsa bile) şunları o dizine toplar:
`import.log`, `import.log.deneme1`, `import_retry.txt`, `ortam.txt` (core_pattern, nproc, bellek), çalışma dizinine düşen `core*` ve
`gdb` varsa `bt.txt` (ilk 8 çerçeve CI özetinde). Dizin `import-evidence-<iş>-<grup>` adıyla 14 gün saklanan artifact olarak yüklenir
(`if: always()`, `if-no-files-found: ignore`). Selftest kopyaları geçici dizinde olduğundan kanıt mutlak yola yazılır. Sınır: runner'ın
`kernel.core_pattern` değeri borulu (apport/systemd) ise core çalışma dizinine düşmez; `ortam.txt` bunu gösterir ve açık noktadır.
`use_multiple_threads=false` bilerek eklenmedi (ölçülmemiş; ayrı karar).
