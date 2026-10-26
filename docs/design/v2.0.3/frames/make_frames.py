#!/usr/bin/env python3
"""Godot 9-slice / sabit doku kaynakları (SVG). Token'lar tokens-v2.0.3.json ile aynıdır.
9-slice kenar payı (patch_margin) dosya adının yanındaki tabloda (README.md)."""
import pathlib
OUT = pathlib.Path(__file__).parent
T = dict(void="#0C0908", t9="#151110", t8="#1F1917", t7="#2D2422", t6="#3B302C", t5="#4C3E38",
         k1="#EFE7D6", k3="#CFC4AE", k5="#A39883", b7="#7A6045", b5="#A88A5C", b3="#D2B47E",
         bo9="#2B0E14", bo7="#5C1D26", bo5="#8F2A36", bo4="#B8404A", am="#E8A24A", demir="#8C8379")
def chamfer(w, h, c, inset=0):
    i = inset
    return f"{i+c},{i} {w-i-c},{i} {w-i},{i+c} {w-i},{h-i-c} {w-i-c},{h-i} {i+c},{h-i} {i},{h-i-c} {i},{i+c}"
def svg(name, w, h, body, defs=""):
    (OUT / f"{name}.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}"><title>{name}</title><defs>{defs}</defs>{body}</svg>', encoding="utf-8")
def levha(name, fill, edge, inner):
    w = h = 144; c = 20
    gus = "".join(f'<path d="M{x} {y} l{dx*22} 0 l{-dx*22} {dy*22}z" fill="{T["b5"]}" opacity=".9"/>' for x, y, dx, dy in ((10, 28, 1, -1), (w - 10, 28, -1, -1), (10, h - 28, 1, 1), (w - 10, h - 28, -1, 1))) if False else ""
    riv = "".join(f'<circle cx="{x}" cy="{y}" r="3.5" fill="{T["b3"]}" stroke="{T["bo9"]}" stroke-width="1.5"/>' for x, y in ((18, 18), (w - 18, 18), (18, h - 18), (w - 18, h - 18)))
    svg(name, w, h, f'<polygon points="{chamfer(w,h,c,2)}" fill="{fill}" stroke="{edge}" stroke-width="4" stroke-linejoin="miter"/>'
        f'<polygon points="{chamfer(w,h,c-6,12)}" fill="none" stroke="{inner}" stroke-width="2"/>{riv}')
levha("levha", T["t8"], T["b7"], T["t6"])
levha("levha-yuksek", T["t7"], T["b7"], T["t5"])
def dugme(name, fill, edge, sw, hi, defs=""):
    w = h = 144; c = 20
    svg(name, w, h, f'<polygon points="{chamfer(w,h,c,3)}" fill="{fill}" stroke="{edge}" stroke-width="{sw}"/>'
        f'<polygon points="{chamfer(w,h,c-4,3+sw+2)}" fill="none" stroke="{hi}" stroke-width="2" opacity=".55"/>', defs)
dugme("dugme-birincil", "url(#g)", T["b5"], 5, T["bo4"], f'<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{T["bo5"]}"/><stop offset="1" stop-color="{T["bo7"]}"/></linearGradient>')
dugme("dugme-dolu", "url(#g)", T["b7"], 4, T["k5"], f'<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{T["t6"]}"/><stop offset="1" stop-color="{T["t7"]}"/></linearGradient>')
dugme("dugme-hayalet", "none", T["b5"], 3, T["b7"])
dugme("dugme-basili", T["t8"], T["b7"], 4, T["t5"])
# başlık lentosu 9-slice (yatay, kenar 60)
svg("lento", 240, 120, f'<polygon points="6,34 34,6 206,6 234,34 234,86 206,114 34,114 6,86" fill="{T["t7"]}" stroke="{T["b5"]}" stroke-width="4"/>'
    f'<polygon points="18,38 38,18 202,18 222,38 222,82 202,102 38,102 18,82" fill="none" stroke="{T["t5"]}" stroke-width="2"/>'
    + "".join(f'<circle cx="{x}" cy="60" r="5" fill="{T["b3"]}" stroke="{T["bo9"]}" stroke-width="2"/>' for x in (22, 218)))
# OYNA tepe süsü: sancak ucu (tek parça, üst kenar ortası)
svg("oyna-tepe", 240, 48, f'<path d="M0 48 L70 48 L96 28 L120 4 L144 28 L170 48 L240 48 L240 44 L174 44 L146 22 L120 -2 L94 22 L66 44 L0 44z" fill="{T["b5"]}"/>'
    f'<path d="M96 48 L120 12 L144 48z" fill="{T["bo5"]}" stroke="{T["b5"]}" stroke-width="3"/><circle cx="120" cy="30" r="5" fill="{T["am"]}"/>')
# anahtar: kor mührü (156x84)
for st in ("ac", "kapali"):
    on = st == "ac"
    slot = T["am"] if on else T["t9"]
    cx = 118 if on else 38
    ring = T["b3"] if on else T["demir"]
    core = T["am"] if on else T["t6"]
    body = (f'<polygon points="{chamfer(156,84,14,2)}" fill="{T["bo7"] if on else T["t8"]}" stroke="{T["b3"] if on else T["t5"]}" stroke-width="4"/>'
            f'<rect x="20" y="30" width="116" height="24" rx="4" fill="{T["void"]}" stroke="{T["b7"]}" stroke-width="2"/>'
            f'<rect x="{22 if on else 80}" y="32" width="{70 if on else 54}" height="20" rx="3" fill="{slot}" opacity="{.95 if on else .5}"/>'
            f'<circle cx="{cx}" cy="42" r="31" fill="{T["t7"]}" stroke="{ring}" stroke-width="5"/>'
            f'<circle cx="{cx}" cy="42" r="19" fill="{core}" stroke="{T["bo9"]}" stroke-width="3"/>'
            + (f'<path d="M{cx} 30 l5 9 -5 12 -5 -12z" fill="{T["k1"]}" opacity=".9"/>' if on else f'<path d="M{cx-8} 34 l16 16 M{cx+8} 34 l-16 16" stroke="{T["t5"]}" stroke-width="3"/>'))
    svg(f"anahtar-{st}", 156, 84, body)
# tutamak madalyon 84
svg("tutamak", 84, 84, f'<circle cx="42" cy="42" r="38" fill="{T["t7"]}" stroke="{T["b5"]}" stroke-width="6"/><circle cx="42" cy="42" r="26" fill="none" stroke="{T["b7"]}" stroke-width="2"/>'
    f'<path d="M42 26 l12 16 -12 16 -12 -16z" fill="{T["b3"]}" stroke="{T["bo9"]}" stroke-width="3"/>')
svg("tutamak-sessiz", 84, 84, f'<circle cx="42" cy="42" r="38" fill="{T["t7"]}" stroke="{T["t5"]}" stroke-width="6"/><path d="M42 26 l12 16 -12 16 -12 -16z" fill="{T["k5"]}" stroke="{T["bo9"]}" stroke-width="3"/>')
# kaydırıcı rayı (9-slice yatay, kenar 24) ve dolgusu
svg("ray", 96, 28, f'<rect x="2" y="2" width="92" height="24" rx="3" fill="{T["t9"]}" stroke="{T["b7"]}" stroke-width="3"/>'
    + "".join(f'<circle cx="{x}" cy="14" r="3.5" fill="{T["b7"]}"/>' for x in (12, 84)))
svg("ray-dolgu", 96, 28, f'<rect x="3" y="3" width="90" height="22" rx="2" fill="url(#g)"/>', f'<linearGradient id="g" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{T["bo5"]}"/><stop offset=".6" stop-color="{T["b5"]}"/><stop offset="1" stop-color="{T["am"]}"/></linearGradient>')
svg("ray-dolgu-sessiz", 96, 28, f'<rect x="3" y="3" width="90" height="22" rx="2" fill="{T["t5"]}"/>')
# kademe plakaları 108x108 (yalnız çerçeve; ikon altta)
def plaka(n, edge, extra="", fill="none", glow=""):
    w = 108
    if n == 4:   # taç çerçeve dışına taşar: doku 108x122, çerçeve 14 px aşağıda
        (OUT / "plaka-4.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -14 108 122" width="108" height="122"><title>plaka-4</title>{glow}<polygon points="{chamfer(w,w,14,3)}" fill="{fill}" stroke="{edge}" stroke-width="5"/>{extra}</svg>', encoding="utf-8"); return
    svg(f"plaka-{n}", w, w, f'{glow}<polygon points="{chamfer(w,w,14,3)}" fill="{fill}" stroke="{edge}" stroke-width="5"/>{extra}')
rv = lambda c: "".join(f'<circle cx="{x}" cy="{y}" r="4.5" fill="{c}" stroke="{T["bo9"]}" stroke-width="2"/>' for x, y in ((17, 17), (91, 17), (17, 91), (91, 91)))
gus = lambda c: "".join(f'<path d="{d}" fill="{c}" stroke="{T["bo9"]}" stroke-width="2" stroke-linejoin="round"/>' for d in ("M5 30 V5 H30 L18 18Z", "M103 30 V5 H78 L90 18Z", "M5 78 V103 H30 L18 90Z", "M103 78 V103 H78 L90 90Z"))
plaka(1, T["demir"], fill=T["t8"])
plaka(2, T["b3"], rv(T["b3"]), fill=T["t8"])
plaka(3, T["am"], gus(T["am"]), fill=T["t8"])
plaka(4, T["am"], gus(T["am"]) + f'<path d="M28 5 L35 -11 L45 1 L54 -14 L63 1 L73 -11 L80 5Z" fill="{T["am"]}" stroke="{T["bo9"]}" stroke-width="2.5" stroke-linejoin="round"/>', fill=T["bo7"],
      glow=f'<polygon points="{chamfer(108,108,14,3)}" fill="none" stroke="{T["am"]}" stroke-width="12" opacity=".25"/>')
plaka("kilitli", T["t5"], fill=T["t9"])
# kademe yolu mühürleri 72x72
def muhur(n, ring, core, mark=""):
    svg(f"muhur-{n}", 72, 72, f'<circle cx="36" cy="36" r="31" fill="{core}" stroke="{ring}" stroke-width="5"/><circle cx="36" cy="36" r="22" fill="none" stroke="{T["bo9"]}" stroke-width="2" opacity=".6"/>{mark}')
muhur("dolu", T["b3"], T["bo7"], f'<path d="M24 37 l9 9 17-20" fill="none" stroke="{T["am"]}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>')
muhur("aktif", T["am"], T["t7"], f'<circle cx="36" cy="36" r="9" fill="{T["am"]}"/>')
muhur("sonuk", T["t5"], T["t8"], f'<circle cx="36" cy="36" r="6" fill="{T["t5"]}"/>')
svg("zincir-halka", 24, 40, f'<rect x="4" y="4" width="16" height="32" rx="8" fill="none" stroke="{T["b5"]}" stroke-width="4"/>')
svg("zincir-halka-sonuk", 24, 40, f'<rect x="4" y="4" width="16" height="32" rx="8" fill="none" stroke="{T["t5"]}" stroke-width="4"/>')
# ayraç (grup başlığı / başlık altı), 9-slice yatay kenar 48
svg("ayrac", 240, 20, f'<path d="M0 10 H96 M144 10 H240" stroke="{T["b7"]}" stroke-width="3"/><path d="M120 2 l12 8 -12 8 -12 -8z" fill="{T["b5"]}" stroke="{T["bo9"]}" stroke-width="2"/>')
# iç yol (kademe listesi) yan çizgi
svg("yol", 8, 64, f'<rect x="2" y="0" width="4" height="64" fill="{T["b5"]}"/>')
