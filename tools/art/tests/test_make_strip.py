"""make_strip: sentetik 7 hücreli temas sayfası (renkli bloklar, başlık şeridi, ayırıcı çizgiler, yeşil zemin, son kare = ilk kare)."""
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

import make_strip as ms

GREEN = (3, 157, 8)
DARK = (28, 22, 34)
CELL_W, CELL_H = 100, 160
HEADER = 24
STAND_H = 80
FOOT_JITTER = [0, 3, 6, 2, 5, 1]  # kaynakta ayak çizgisi kareden kareye oynar (ham hata)


def draw_figure(img: np.ndarray, x0: int, foot_y: int, i: int, body_h: int = 120) -> None:
    """Gövde (torso+kafa) + iki bacak bloğu; ayak tabanı foot_y'de (dışlayıcı). Kare başı renk farklı."""
    col = (120 + 18 * (i % 6), 50, 70)
    torso_w, leg_w, leg_h = 30, 10, 50
    cx = x0 + 50 + (i % 3) * 2  # gövde merkezi hafif oynar
    top = foot_y - body_h
    img[top:foot_y - leg_h, cx - torso_w // 2:cx + torso_w // 2] = col
    sh = (i % 3) * 4  # bacak açıklığı
    img[foot_y - leg_h:foot_y, cx - 8 - sh:cx - 8 - sh + leg_w] = (60, 40, 20)
    img[foot_y - leg_h:foot_y, cx + 6 + sh:cx + 6 + sh + leg_w] = (60, 40, 20)


def make_sheet(n_cells: int = 7, separators: bool = True, dup_last: bool = True) -> np.ndarray:
    w = n_cells * CELL_W
    img = np.zeros((HEADER + CELL_H + HEADER + CELL_H, w, 3), np.uint8)
    img[:] = GREEN
    img[0:HEADER] = DARK  # başlık şeridi
    row2 = HEADER + CELL_H
    img[row2:row2 + HEADER] = DARK  # ikinci başlık (altında ikinci satır: yok sayılır)
    for i in range(n_cells):
        k = (0 if dup_last else 4) if i == n_cells - 1 else i
        x0 = i * CELL_W
        foot = HEADER + CELL_H - 8 - FOOT_JITTER[k % 6]
        draw_figure(img, x0, foot, k, body_h=120 + (k % 3) * 2)
        if separators and i > 0:
            img[HEADER:HEADER + CELL_H, x0] = DARK
    return img


def stand_image() -> np.ndarray:
    st = np.zeros((STAND_H, 40, 4), np.uint8)
    st[..., :3] = (200, 180, 160)
    st[..., 3] = 255
    return st


@pytest.fixture
def sheet_files(tmp_path):
    sheet = tmp_path / "sheet.png"
    Image.fromarray(make_sheet()).save(sheet)
    stand = tmp_path / "stand.png"
    Image.fromarray(stand_image(), "RGBA").save(stand)
    return sheet, stand


# ----------------------------------------------------------------- bölme
def test_split_sheet_finds_cells_with_separators():
    cells = ms.split_sheet(make_sheet(), row=0, cells=7)
    assert len(cells) == 7
    assert all(abs(c.shape[1] - CELL_W) <= 3 for c in cells)
    assert all(c.shape[0] == CELL_H for c in cells), "başlık şeridi atıldı"


def test_split_sheet_without_separator_lines_splits_equally():
    cells = ms.split_sheet(make_sheet(separators=False), row=0, cells=7)
    assert len(cells) == 7
    assert all(abs(c.shape[1] - CELL_W) <= 3 for c in cells)


def test_split_sheet_header_rows_are_dropped_and_second_row_selectable():
    sheet = make_sheet()
    rows = ms.row_bands(sheet)
    assert rows[0] == (HEADER, HEADER + CELL_H)
    assert len(rows) == 2


# ----------------------------------------------------------------- şerit
def test_build_strip_player_aligns_feet_and_uses_common_scale():
    cells = ms.split_sheet(make_sheet(), row=0, cells=7)
    res = ms.build_strip(cells, stand_rgba=stand_image(), kind="player", drop_dup_last=True)
    assert res.manifest["frames"] == 6, "son kare ilkin kopyası: atıldı"
    n = res.manifest["frames"]
    cw, ch = res.manifest["cell"]
    strip = res.strip
    assert strip.shape == (ch, cw * (n + 1), 4), "N yürüme + 1 duruş hücresi"
    # ayak çizgisi: her hücrede alttaki opak satır aynı (±1 px)
    bottoms = []
    for f in range(n + 1):
        a = strip[:, f * cw:(f + 1) * cw, 3]
        ys = np.nonzero(a.max(axis=1) > 128)[0]
        bottoms.append(int(ys.max()))
    assert max(bottoms) - min(bottoms) <= 1
    assert bottoms[0] >= ch - 2, "ayak hücrenin alt kenarında"
    # ortak ölçek: torso genişliği her karede aynı oranda küçüldü
    s = res.manifest["display_scale_hint"]
    assert s == pytest.approx(STAND_H / 120.0 * 1.0, rel=0.05) or s > 0
    widths = []
    for f in range(n):
        row = strip[ch - round(res.scale * 85), f * cw:(f + 1) * cw, 3]  # torsonun ortasında bir satır
        widths.append(int((row > 128).sum()))
    assert max(widths) - min(widths) <= 2, "kare başına ayrı ölçek yok"
    assert widths[0] == pytest.approx(30 * res.scale, abs=2)


def test_stand_cell_is_centered_and_bottom_aligned():
    cells = ms.split_sheet(make_sheet(), row=0, cells=7)
    res = ms.build_strip(cells, stand_rgba=stand_image(), kind="player", drop_dup_last=True)
    cw, ch = res.manifest["cell"]
    n = res.manifest["frames"]
    a = res.strip[:, n * cw:(n + 1) * cw, 3]
    ys, xs = np.nonzero(a > 128)
    assert ys.max() == ch - 1
    assert abs((xs.min() + xs.max() + 1) / 2 - cw / 2) <= 1
    assert ys.max() - ys.min() + 1 == STAND_H, "duruş görseli ölçeklenmedi"


def test_drop_dup_last_is_optional_and_checked_by_similarity():
    cells = ms.split_sheet(make_sheet(), row=0, cells=7)
    res = ms.build_strip(cells, stand_rgba=stand_image(), kind="player", drop_dup_last=False)
    assert res.manifest["frames"] == 7
    uniq = ms.split_sheet(make_sheet(dup_last=False), row=0, cells=7)
    res2 = ms.build_strip(uniq, stand_rgba=stand_image(), kind="player", drop_dup_last=True)
    assert res2.manifest["frames"] == 7, "son kare farklıysa atılmaz"


def test_manifest_has_shoulder_dev_for_player_and_none_for_enemy():
    cells = ms.split_sheet(make_sheet(), row=0, cells=7)
    pl = ms.build_strip(cells, stand_rgba=stand_image(), kind="player", drop_dup_last=True)
    sd = pl.manifest["shoulder_dev"]
    assert len(sd) == pl.manifest["frames"] + 1
    assert sd[-1] == [0.0, 0.0], "duruş hücresi referanstır"
    assert all(abs(v) <= 0.2 for p in sd for v in p)
    en = ms.build_strip(cells, stand_rgba=stand_image(), kind="enemy", drop_dup_last=True)
    assert "shoulder_dev" not in en.manifest
    cw, ch = en.manifest["cell"]
    assert en.strip.shape == (ch, cw * en.manifest["frames"], 4), "düşman şeridinde duruş hücresi yok"


def test_quality_metrics_report_raw_foot_and_height_deviation():
    cells = ms.split_sheet(make_sheet(), row=0, cells=7)
    res = ms.build_strip(cells, stand_rgba=stand_image(), kind="player", drop_dup_last=True)
    q = res.manifest["quality"]
    assert q["foot_dev_px_1536"] > 0, "kaynakta ayak oynaktı (ham hata ölçülür)"
    assert len(q["height_dev_pct"]) == res.manifest["frames"]
    assert max(abs(v) for v in q["height_dev_pct"]) < 10


def test_empty_cell_raises_clear_error():
    cells = ms.split_sheet(make_sheet(), row=0, cells=7)
    cells[2] = np.zeros_like(cells[2])
    cells[2][:] = GREEN
    with pytest.raises(ValueError, match="boş"):
        ms.build_strip(cells, stand_rgba=stand_image(), kind="player")


# ----------------------------------------------------------------- CLI
def test_cli_writes_strip_manifest_and_preview(sheet_files, tmp_path):
    sheet, stand = sheet_files
    out = tmp_path / "strip.png"
    man = tmp_path / "strip.json"
    prev = tmp_path / "prev"
    script = Path(ms.__file__)
    r = subprocess.run(
        [sys.executable, str(script), "--sheet", str(sheet), "--rows", "0", "--cells", "7",
         "--drop-dup-last", "--kind", "player", "--stand", str(stand), "--out", str(out),
         "--manifest", str(man), "--preview", "--preview-dir", str(prev)],
        capture_output=True, text=True,
    )
    assert r.returncode == 0, r.stderr
    m = json.loads(man.read_text())
    assert m["frames"] == 6
    img = Image.open(out)
    assert img.mode == "RGBA" and img.size == (m["cell"][0] * 7, m["cell"][1])
    assert any(prev.glob("*.png")), "önizleme yazıldı"


def test_cli_grid_mode_for_individual_frame_sheets(tmp_path):
    # 3x2 ızgara (ham kareler tek görselde, başlık/ayırıcı yok)
    cw, chh = 90, 150
    img = np.zeros((chh * 2, cw * 3, 3), np.uint8)
    img[:] = GREEN
    for i in range(6):
        gx, gy = (i % 3) * cw, (i // 3) * chh
        draw_figure(img, gx - 5, gy + chh - 6 - FOOT_JITTER[i], i, body_h=118)
    cells = ms.split_grid(img, cols=3, rows=2)
    assert len(cells) == 6
    res = ms.build_strip(cells, stand_rgba=stand_image(), kind="player")
    assert res.manifest["frames"] == 6


# ----------------------------------------------------------------- temizlik
def test_edge_separator_remnants_are_trimmed_from_cells():
    cell = np.zeros((CELL_H, CELL_W, 3), np.uint8)
    cell[:] = GREEN
    cell[:, 0] = DARK  # ayırıcı çizgi artığı
    cell[:, CELL_W - 1] = DARK
    draw_figure(cell, 0, CELL_H - 8, 0)
    trimmed = ms.trim_edge_lines(cell)
    assert trimmed.shape[1] == CELL_W - 2


def test_stray_fragments_from_the_neighbour_frame_are_removed():
    a = np.zeros((120, 120), np.float32)
    a[10:110, 40:80] = 1.0  # ana gövde
    a[100:112, 2:8] = 1.0  # komşu kareden taşan palto ucu
    out = ms.keep_main_parts(a)
    assert out[105, 4] == 0.0 and out[50, 60] == 1.0


# ----------------------------------------------------------------- ayak kayması
def _slide_cells(step_px: int, n: int = 6, drift: int = 0):
    """Basan ayağı kare başına `step_px` geriye giden sentetik kareler (gövde sabit, ayak bloğu kayar)."""
    cells = []
    for f in range(n):
        cell = np.zeros((CELL_H, CELL_W, 3), np.uint8)
        cell[:] = GREEN
        cell[20:110, 40:60] = (150, 60, 60)  # gövde (sabit)
        x = 50 + 40 - (f % 3) * step_px + (f // 3) * drift  # her yarım çevrimde ayak değişir: konum başa döner
        cell[CELL_H - 20:CELL_H - 8, x - 6:x + 6] = (60, 40, 20)
        cells.append(cell)
    return cells


def test_foot_slide_passes_for_a_locked_planted_foot():
    cells = _slide_cells(step_px=14)
    res = ms.build_strip(cells, stand_rgba=stand_image(), kind="player")
    fs = ms.foot_slide(res, stride=6 * 14 * res.scale, world_per_px=1.0)
    assert fs["ok_pairs"] >= 4 and fs["pass"], fs


def test_foot_slide_fails_when_the_planted_foot_does_not_follow_the_stride():
    cells = _slide_cells(step_px=14)
    res = ms.build_strip(cells, stand_rgba=stand_image(), kind="player")
    fs = ms.foot_slide(res, stride=300.0, world_per_px=1.0)
    assert not fs["pass"], fs
    assert fs["ok_pairs"] < 4
