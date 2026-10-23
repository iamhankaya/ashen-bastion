#!/usr/bin/env python3
"""test/fixtures/data_valid/ ve data_bad_<kod>/ üretir (çıktı commit'lidir; şema değişince yeniden üretilir).

data_bad_<kod>/ bir BİNDİRME dizinidir: yalnız değişen dosyaları içerir; test, geçerli fixture'ın kopyası üzerine
bindirir. `<yol>.deleted` dosyası ilgili dosyayı siler. Dizin adındaki <kod>, validate() çıktısında "[kod]" olarak
aranır (GameData.ERROR_CODES ile bire bir örtüşür).
"""
import copy
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "test" / "fixtures"


def lv5(fn):
    return [fn(n) for n in range(1, 6)]


def active(sid, name, tags, levels, descs=None):
    return {
        "id": sid, "kind": "active", "name": name, "icon": f"placeholder:{sid}", "max_level": 5,
        "tags": tags, "behavior": sid, "levels": levels,
        "desc": descs or [f"{name} seviye {i}." for i in range(1, 6)],
    }


def passive(sid, name, tags, fn):
    return {
        "id": sid, "kind": "passive", "name": name, "icon": f"placeholder:{sid}", "max_level": 5,
        "tags": tags, "levels": lv5(fn), "desc": [f"{name} seviye {i}." for i in range(1, 6)],
    }


def enemy(eid, name, hp, speed, dmg, radius, armor, xp, ai, sprite, h, tint="#ffffff", scales=True, **extra):
    d = {"id": eid, "name": name, "hp": hp, "speed": speed, "dmg": dmg, "radius": radius, "armor": armor,
         "xp": xp, "ai": ai, "scales_with_time": scales, "sprite": f"placeholder:{sprite}",
         "display_height": h, "tint": tint}
    d.update(extra)
    return d


GUNSLINGER = json.load(open(Path(__file__).resolve().parents[2] / "data/characters/gunslinger.json"))

VALID = {
    "characters/gunslinger.json": GUNSLINGER,
    "skills/cift_tabanca.json": json.load(open(Path(__file__).resolve().parents[2] / "data/skills/cift_tabanca.json")),
    "skills/seken_mermi.json": active(
        "seken_mermi", "Seken Mermi", ["rhythm"],
        [{"every_n": n, "bounces": b, "damage_mult": m} for n, b, m in
         [(3, 2, 1.0), (3, 3, 1.1), (3, 3, 1.2), (2, 4, 1.3), (2, 5, 1.4)]]),
    "skills/son_mermi_patlar.json": active(
        "son_mermi_patlar", "Son Mermi Patlar", ["rhythm"],
        [{"ex_damage": d, "ex_radius": r} for d, r in [(50, 100), (70, 115), (90, 130), (115, 150), (150, 170)]]),
    "skills/barut_kesesi.json": passive(
        "barut_kesesi", "Barut Kesesi", [],
        lambda n: {"area_mult": round(0.12 * n, 4), "explosion_dmg_mult": round(0.08 * n, 4)}),
    "skills/hizli_doldurma.json": passive(
        "hizli_doldurma", "Hızlı Doldurma", ["rhythm"], lambda n: {"reload_time_mult": round(-0.10 * n, 4)}),
    "skills/zincirleme_patlama.json": {
        "id": "zincirleme_patlama", "kind": "evolution", "name": "Zincirleme Patlama",
        "icon": "placeholder:zincirleme_patlama", "max_level": 1, "tags": ["rhythm"],
        "behavior": "zincirleme_patlama",
        "levels": [{"every_n": 2, "bounces": 8, "ex_damage": 40, "ex_radius": 90}],
        "desc": ["Her 2. kurşun seker, her sekmede patlar."],
        "requires": {"active": "seken_mermi", "active_level": 5, "passive": "barut_kesesi", "passive_min_level": 1},
    },
    "enemies/curumus_piyade.json": enemy(
        "curumus_piyade", "Çürümüş Piyade", 30, 95, 6, 26, 0, 1, "ground", "piyade", 192,
        anim={"kind": "crawl", "hz": 1.1, "bob": 5, "rot": 5, "sq": 0.05, "lean": 4, "hover": 0, "knock": 10,
              "hit_sq": 0.12, "hit_rot": 0, "cycle": 72, "death": "collapse", "death_ms": 420, "alpha": [1, 1]}),
    "enemies/les_kargasi.json": enemy(
        "les_kargasi", "Leş Kargası", 12, 210, 4, 18, 0, 1, "air", "karga", 192,
        anim={"kind": "flap", "hz": 3.0, "bob": 7, "rot": 12, "hover": 36, "death": "fall", "death_ms": 420}),
    "enemies/elit_piyade.json": enemy(
        "elit_piyade", "Elit Piyade", 1800, 110, 14, 60, 2, 80, "elite", "piyade", 422, "#8a2a3a", scales=False),
    "enemies/kale_lordu.json": enemy(
        "kale_lordu", "Düşmüş Kale Lordu", 45000, 80, 40, 72, 6, 500, "lord", "kale_lordu", 384, scales=False,
        summon={"type": "curumus_piyade", "every": 8, "count": 12,
                "enrage_hp_frac": 0.5, "enrage_speed_mult": 1.4, "enrage_every": 5},
        anim={"kind": "stomp", "hz": 0.55, "bob": 6, "rot": 2.5, "death": "lord", "death_ms": 900}),
    "pickups.json": json.load(open(Path(__file__).resolve().parents[2] / "data/pickups.json")),
    "score.json": {
        "kill_points": {"curumus_piyade": 10, "les_kargasi": 8, "elit_piyade": 400, "kale_lordu": 10000},
        "streak": {"window": 3.0, "tiers": [[0, 1], [10, 2], [25, 3], [50, 4], [100, 5]]},
        "evolution_bonus": 2000, "survival_per_sec": 5, "lord_bonus": 25000, "display_cap": 99999999,
    },
    "waves.json": {
        "end_time": 1200,
        "rows": [
            {"kind": "rate", "type": "curumus_piyade", "from": 0, "to": 1200, "rate": [0.8, 3.5]},
            {"kind": "group", "type": "les_kargasi", "from": 90, "to": 1200, "group": [6, 14], "every": [26, 12]},
            {"kind": "burst", "type": "curumus_piyade", "at": 480, "count": 50, "ring": True},
            {"kind": "boss", "type": "elit_piyade", "at": 300, "warn": 5},
            {"kind": "boss", "type": "kale_lordu", "at": 1200, "warn": 5},
        ],
        "after_lord": {"piyade_rate_mult": 0.5, "karga_stop": True},
    },
}


def mut(path, fn):
    d = copy.deepcopy(VALID[path])
    fn(d)
    return d


def row(i, **kw):
    def f(w):
        w["rows"][i].update(kw)
    return f


BAD = {
    "bad_json": {"skills/seken_mermi.json": "{ bu json degil"},
    "missing_file": {"waves.json.deleted": ""},
    "not_object": {"enemies/les_kargasi.json": [1, 2]},
    "missing_field": {"enemies/curumus_piyade.json": mut("enemies/curumus_piyade.json", lambda d: d.pop("hp"))},
    "bad_type": {"enemies/curumus_piyade.json": mut("enemies/curumus_piyade.json", lambda d: d.update(hp="30"))},
    "out_of_range": {"enemies/curumus_piyade.json": mut("enemies/curumus_piyade.json", lambda d: d.update(hp=-5))},
    "dup_id": {"skills/dup_seken.json": mut("skills/seken_mermi.json", lambda d: None)},
    "id_filename": {"enemies/les_kargasi.json": mut("enemies/les_kargasi.json", lambda d: d.update(id="karga_x"))},
    "bad_kind": {"skills/barut_kesesi.json": mut("skills/barut_kesesi.json", lambda d: d.update(kind="boost"))},
    "levels_length": {"skills/seken_mermi.json": mut("skills/seken_mermi.json", lambda d: d["levels"].pop())},
    "levels_keys": {"skills/seken_mermi.json": mut("skills/seken_mermi.json", lambda d: d["levels"][2].pop("bounces"))},
    "levels_monotonic": {"skills/cift_tabanca.json": mut(
        "skills/cift_tabanca.json", lambda d: d["levels"][2].update(damage=10))},
    "passive_key": {"skills/barut_kesesi.json": mut(
        "skills/barut_kesesi.json", lambda d: [lv.update(luck=lv.pop("area_mult")) for lv in d["levels"]])},
    "behavior_missing": {"skills/cift_tabanca.json": mut(
        "skills/cift_tabanca.json", lambda d: d.update(behavior="yok_boyle_bir"))},
    "requires_unexpected": {"skills/seken_mermi.json": mut(
        "skills/seken_mermi.json", lambda d: d.update(requires={"active": "cift_tabanca"}))},
    "requires_ref": {"skills/zincirleme_patlama.json": mut(
        "skills/zincirleme_patlama.json", lambda d: d["requires"].update(active="olmayan"))},
    "requires_kind": {"skills/zincirleme_patlama.json": mut(
        "skills/zincirleme_patlama.json", lambda d: d["requires"].update(passive="seken_mermi"))},
    "requires_level": {"skills/zincirleme_patlama.json": mut(
        "skills/zincirleme_patlama.json", lambda d: d["requires"].update(active_level=4))},
    "dup_evolution": {"skills/baska_evrim.json": mut(
        "skills/zincirleme_patlama.json", lambda d: d.update(id="baska_evrim"))},
    "bad_ai": {"enemies/curumus_piyade.json": mut("enemies/curumus_piyade.json", lambda d: d.update(ai="swim"))},
    "asset_missing": {"enemies/curumus_piyade.json": mut(
        "enemies/curumus_piyade.json", lambda d: d.update(sprite="gfx/yok/olmayan"))},
    "unknown_enemy": {"waves.json": mut("waves.json", row(0, type="hayalet"))},
    "wave_range": {"waves.json": mut("waves.json", row(0, **{"from": 600, "to": 100}))},
    "wave_kind": {"waves.json": mut("waves.json", row(0, kind="spiral"))},
    "wave_boss_time": {"waves.json": mut("waves.json", row(4, at=1100))},
    "wave_enemy_ai": {"waves.json": mut("waves.json", row(3, type="curumus_piyade"))},
    "wave_unknown_key": {"waves.json": mut("waves.json", lambda w: w.update(extra=1))},
    "unknown_key": {"enemies/les_kargasi.json": mut("enemies/les_kargasi.json", lambda d: d.update(sped=1))},
    "pickup_weight": {"pickups.json": mut("pickups.json", lambda d: [k.update(weight=0) for k in d["kinds"]])},
    "score_tiers": {"score.json": mut("score.json", lambda d: d["streak"].update(tiers=[[0, 1], [10, 3], [25, 2]]))},
    "no_character": {"characters/gunslinger.json.deleted": ""},
    "rhythm_count": {
        "skills/seken_mermi.json": mut("skills/seken_mermi.json", lambda d: d.update(tags=[])),
        "skills/son_mermi_patlar.json": mut("skills/son_mermi_patlar.json", lambda d: d.update(tags=[])),
    },
}


def write(base: Path, rel: str, content):
    p = base / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(content, str):
        p.write_text(content)
    else:
        p.write_text(json.dumps(content, indent=2, ensure_ascii=False) + "\n")


def main():
    for d in ROOT.glob("data_*"):
        shutil.rmtree(d)
    for rel, c in VALID.items():
        write(ROOT / "data_valid", rel, c)
    for code, files in BAD.items():
        for rel, c in files.items():
            write(ROOT / f"data_bad_{code}", rel, c)


if __name__ == "__main__":
    main()
