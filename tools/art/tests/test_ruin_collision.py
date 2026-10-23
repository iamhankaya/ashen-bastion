import json

import ruin_collision as rc


def test_committed_ruins_json_is_up_to_date():
    # data/ruins.json elle değil araçla güncellenir: araç çıktısı commit'liyle birebir aynı olmalı
    assert rc.RUINS.read_text() == json.dumps(rc.build(), indent=2) + "\n"


def test_solid_rule_taller_than_the_player_and_chain_follows_the_base():
    for rec in rc.build():
        im = rc.sprite(rec)
        tall = rc.world_height(rec, im) >= rc.SOLID_MIN_HEIGHT
        assert rec["solid"] == tall, rec["id"]
        assert ("collision" in rec) == tall, rec["id"]
        for c in rec.get("collision", []):
            assert 20 <= c["r"] <= 50, rec["id"]
            assert abs(c["x"]) < 500 and abs(c["y"]) < 200, rec["id"]
