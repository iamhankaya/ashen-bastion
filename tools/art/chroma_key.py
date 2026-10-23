"""Yeşil arka plan anahtarlama (chroma key) çekirdeği: saf numpy/scipy, dosya girişi yok.

Algoritma (plan: "Sanat işleme aracı"):
  d     = G - max(R, B)                      (yeşil baskınlığı)
  alpha = 1 - clamp((d - d_lo) / (d_hi - d_lo), 0, 1)
Arka plan d ~ 125-200, zeytin/yosun bitki d <= ~20 olduğu için bitki korunur.
Sonra: yarı saydam piksellerde arka plan karışımının çıkarılması (unmix),
kenar yeşil temizleme (despill), isteğe bağlı duman temizliği, saydam/zayıf
piksellere komşu renk doldurma.
"""
from __future__ import annotations

import numpy as np
from scipy import ndimage

D_LO = 30.0
D_HI = 110.0
# Bu eşiğin üstündeki d değerleri "kesin arka plan" sayılır (yerel arka plan rengi kestirimi için).
BG_SURE_D = 120.0


def green_dominance(rgb: np.ndarray) -> np.ndarray:
    """d = G - max(R, B); rgb float/uint8 (H,W,3)."""
    c = rgb.astype(np.float32)
    return c[..., 1] - np.maximum(c[..., 0], c[..., 2])


def key_alpha(rgb: np.ndarray, d_lo: float = D_LO, d_hi: float = D_HI) -> np.ndarray:
    """Küresel anahtar: alpha float32 0..1."""
    d = green_dominance(rgb)
    return (1.0 - np.clip((d - d_lo) / (d_hi - d_lo), 0.0, 1.0)).astype(np.float32)


def nearest_fill(rgb: np.ndarray, valid: np.ndarray) -> np.ndarray:
    """valid==False piksellerin rengini en yakın valid pikselinkiyle doldurur (float32 kopya)."""
    out = rgb.astype(np.float32).copy()
    if valid.all() or not valid.any():
        return out
    idx = ndimage.distance_transform_edt(~valid, return_distances=False, return_indices=True)
    return out[idx[0], idx[1]]


def local_background(rgb: np.ndarray, d: np.ndarray) -> np.ndarray:
    """Her piksel için en yakın 'kesin arka plan' pikselinin rengi (düzgün olmayan arka planlar için)."""
    sure = d >= BG_SURE_D
    if not sure.any():
        return np.broadcast_to(np.array([4, 156, 8], np.float32), rgb.shape).copy()
    return nearest_fill(rgb, sure)


def unmix_background(rgb: np.ndarray, alpha: np.ndarray, bg: np.ndarray, a_min: float = 0.12) -> np.ndarray:
    """Yarı saydam piksellerde I = a*F + (1-a)*B  ->  F = (I - (1-a)*B)/a (a>=a_min)."""
    c = rgb.astype(np.float32)
    a = alpha[..., None]
    part = (alpha >= a_min) & (alpha < 0.999)
    f = (c - (1.0 - a) * bg) / np.maximum(a, a_min)
    out = c.copy()
    out[part] = np.clip(f[part], 0, 255)
    return out


def despill(rgb: np.ndarray, alpha: np.ndarray, band: int = 2, cap_partial: float = 0.0,
            cap_band: float = 6.0) -> np.ndarray:
    """Kenar yeşil sızıntısı temizleme: G <= max(R,B) + cap.

    Yalnız yarı saydam pikseller (cap_partial) ve onlara/saydamlığa `band` px yakın opak
    pikseller (cap_band) etkilenir; içerideki zeytin bitki (d<=~20) dokunulmaz.
    """
    out = rgb.astype(np.float32).copy()
    partial = (alpha > 0.0) & (alpha < 0.999)
    edge = ndimage.binary_dilation(alpha < 0.999, iterations=band) & (alpha > 0.0)
    g = out[..., 1]
    mx = np.maximum(out[..., 0], out[..., 2])
    avg = 0.5 * (out[..., 0] + out[..., 2])
    # opak ama kenara yakın: G <= max(R,B)+cap_band ; yarı saydam: "ortalama despill" G <= (R+B)/2 + cap_partial
    g = np.where(edge & ~partial, np.minimum(g, mx + cap_band), g)
    g = np.where(partial, np.minimum(g, np.minimum(avg + cap_partial, mx)), g)
    out[..., 1] = g
    return out


def despeckle(alpha: np.ndarray, min_area: int = 30, thr: float = 0.1) -> np.ndarray:
    """Çok küçük izole opak lekeleri (gürültü) siler."""
    lab, n = ndimage.label(alpha > thr, structure=np.ones((3, 3)))
    if n == 0:
        return alpha
    area = ndimage.sum(np.ones_like(alpha), lab, index=np.arange(1, n + 1))
    keep = np.concatenate([[False], area >= min_area])
    return np.where(keep[lab], alpha, 0.0).astype(np.float32)


def disk(r: int) -> np.ndarray:
    y, x = np.ogrid[-r:r + 1, -r:r + 1]
    return (x * x + y * y) <= r * r


def smoke_cleanup(rgb: np.ndarray, alpha: np.ndarray, open_r: int = 4, grow: int = 5,
                  max_v: float = 120.0, min_d: float = 2.0, opaque_below: float = 0.9):
    """Gövdeden taşan duman/kor dalgalarını siler (oyunda GPUParticles2D ile eklenir).

    Yeşil zemin üstündeki yarı saydam koyu duman, anahtarlamadan sonra yeşil renkli (d>=min_d) koyu
    (max(R,G,B)<=max_v) ya da yarı saydam (alpha<opaque_below) piksel olarak kalır = "duman adayı".
    Aday olmayan opak piksellerin morfolojik açılması (open_r) + genişletme (grow) = çekirdek.
    Çekirdek dışındaki adaylar silinir; çekirdek içindeki adaylar yalnız yeşilden arındırılır
    (G <= (R+B)/2). Yeşil tonu taşımayan mor/siyah duman ayırt edilemez (koyu zırhtan farksız) ve kalır.
    Dönüş: (rgb, alpha).
    """
    c = rgb.astype(np.float32)
    d = green_dominance(c)
    cand = (alpha > 0) & (((c.max(axis=2) <= max_v) & (d >= min_d)) | (alpha < opaque_below))
    solid = (alpha >= opaque_below) & ~cand
    core = ndimage.binary_opening(solid, structure=disk(open_r))
    core = ndimage.binary_dilation(core, structure=disk(grow))
    out_a = alpha.copy()
    out_a[cand & ~core] = 0.0
    keep = cand & core
    avg = 0.5 * (c[..., 0] + c[..., 2])
    c[..., 1] = np.where(keep, np.minimum(c[..., 1], avg), c[..., 1])
    return c, out_a


def key_image(rgb_u8: np.ndarray, *, d_lo: float = D_LO, d_hi: float = D_HI,
              smoke: dict | None = None, min_speck: int = 30):
    """Tam anahtarlama: (rgb float32 HxWx3, alpha float32 HxW) döndürür.

    rgb_u8: (H,W,3) uint8. alpha<=0.5 piksellerin rengi (unmix gürültüsü / saydam)
    en yakın güvenilir opak pikselden doldurulur: kenarda yeşil/koyu halo kalmaz.
    """
    rgb = rgb_u8.astype(np.float32)
    d = green_dominance(rgb)
    alpha = key_alpha(rgb, d_lo, d_hi)
    bg = local_background(rgb, d)
    rgb = unmix_background(rgb, alpha, bg)
    rgb = despill(rgb, alpha)
    if smoke:
        rgb, alpha = smoke_cleanup(rgb, alpha, **smoke)
    alpha = despeckle(alpha, min_speck)
    rgb = nearest_fill(rgb, alpha > 0.5)
    return rgb, alpha
