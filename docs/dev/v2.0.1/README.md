# v2.0.1 yürüme omuz kayması (T20261024-72) — önce/sonra

`walk_before.png` = v2.0 (gövde eğimi ayak pivotundan), `walk_after.png` = v2.0.1 (bel pivotu, kol pivotu gövde omzuna bağlı).
Üretim (v1.1.1 ile aynı betik, senaryo `walk`, varsayılan YUMUŞAK kademe):

```
xvfb-run -a -s "-screen 0 720x720x24" godot --path . --rendering-driver opengl3 --resolution 720x720 \
  -s res://tools/capture/shots_anim.gd -- <dizin> walk
python3 tools/capture/anim_montage.py <dizin> walk docs/dev/v2.0.1/walk_after.png 2
```

Gövde eğimi artık ayak yerine `PlayerView.HIP_FRAC` (0,65·H) yüksekliğinde döner; omuz (~0,8·H) pivottan ~0,15·H (30 px) uzakta kalır.
Sim omzuna kenet (`SHOULDER_TOL`, `_clamp_shoulder`) kaldırıldı: kol pivotu hep gövdenin omzundadır. Ölçüm: `test/unit/test_player_shoulder_drift.gd`
(eğim kayması |(R−I)(q−bel)| ≤ 6 px, üç kademe × iki bakış; duruşta 0). Ölümde devrilme ayak pivotunda kalır.
