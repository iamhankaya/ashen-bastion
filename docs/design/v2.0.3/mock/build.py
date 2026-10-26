#!/usr/bin/env python3
"""v2.0.3 maketleri (statik HTML, 1080x2400). Çalıştır: python3 build.py && node shoot.js"""
import pathlib
HERE = pathlib.Path(__file__).parent
R = "../../../../"
ACH = R + "assets/ui/achievements/"
HERO = "../../../ui/mockups/assets/gunslinger-atis-keyed.png"
ORB = R + "art/source/gem-orbs/"

def page(name, title, body, aria, h=2400):
    (HERE / f"{name}.html").write_text(
        '<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=1080">'
        f'<title>{title} — Ashen Bastion v2.0.3 maketi</title><link rel="stylesheet" href="mock.css"><style>body{{height:{h}px}}</style></head>'
        f'<body><main class="screen" style="height:{h}px" aria-label="{aria}">{body}</main></body></html>', encoding="utf-8")

def call(x, y, w, h, label, inside=False):
    return f'<div class="call" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"><b class="{"in" if inside else ""}">{label}</b></div>'

BG = '<div class="abs" style="inset:0;background:radial-gradient(ellipse 80% 40% at 50% 8%,rgba(92,29,38,.5),transparent 70%),#171020"></div>'
PERSON = '<svg width="52" height="52" viewBox="0 0 52 52"><circle cx="26" cy="16" r="9" fill="#D2B47E" stroke="#2B0E14" stroke-width="3"/><path d="M8 46c0-11 8-18 18-18s18 7 18 18z" fill="#D2B47E" stroke="#2B0E14" stroke-width="3"/></svg>'
STAR = '<svg width="52" height="52" viewBox="0 0 52 52"><path d="M26 4l6.5 14.5 15.5 1.7-11.6 10.6 3.3 15.7L26 38.6 12.3 46.5l3.3-15.7L4 20.2l15.5-1.7z" fill="#D2B47E" stroke="#2B0E14" stroke-width="3" stroke-linejoin="round"/></svg>'
TROPHY = '<svg width="52" height="52" viewBox="0 0 52 52"><path d="M14 6H38V22C38 30 32 35 26 35C20 35 14 30 14 22Z" fill="#D2B47E" stroke="#2B0E14" stroke-width="3"/><path d="M14 10H6C6 20 10 24 15 25M38 10H46C46 20 42 24 37 25" fill="none" stroke="#D2B47E" stroke-width="4"/><rect x="22" y="35" width="8" height="8" fill="#A88A5C" stroke="#2B0E14" stroke-width="3"/><rect x="14" y="43" width="24" height="6" rx="2" fill="#7A6045" stroke="#2B0E14" stroke-width="3"/></svg>'
GEAR = '<svg width="52" height="52" viewBox="0 0 52 52"><g fill="#D2B47E" stroke="#2B0E14" stroke-width="3" stroke-linejoin="round"><path d="M22 3h8l1.5 6.5 4.5 1.9 5.7-3.5 5.6 5.6-3.5 5.7 1.9 4.5L52 22v8l-6.3 1.5-1.9 4.5 3.5 5.7-5.6 5.6-5.7-3.5-4.5 1.9L30 52h-8l-1.5-6.3-4.5-1.9-5.7 3.5-5.6-5.6 3.5-5.7-1.9-4.5L0 30v-8l6.3-1.5 1.9-4.5-3.5-5.7 5.6-5.6 5.7 3.5 4.5-1.9z" transform="translate(0 0) scale(.96) translate(1 1)"/></g><circle cx="26" cy="26" r="8" fill="#171020" stroke="#2B0E14" stroke-width="3"/></svg>'
LOCK = '<svg class="lkb" width="40" height="40" viewBox="0 0 48 48"><path d="M14 22V16a10 10 0 0 1 20 0v6" fill="none" stroke="#CFC4AE" stroke-width="5"/><rect x="9" y="22" width="30" height="22" rx="4" fill="#CFC4AE" stroke="#2B0E14" stroke-width="3"/></svg>'
CHECK = '<svg width="40" height="40" viewBox="0 0 48 48"><circle cx="24" cy="24" r="21" fill="#2B0E14" stroke="#E8A24A" stroke-width="4"/><path d="M13 25l8 8 14-17" fill="none" stroke="#E8A24A" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/></svg>'

# ============================================================ 01 Ana sayfa
def menu(name="01-ana-sayfa", sel="Gunslinger", ach="31/53", anat=False, big=False):
    if not big:
        top, hero_h, hero_top = 1763, 1100, 560
        col = ('<div class="btn" style="height:180px;font-size:64px;letter-spacing:.14em">OYNA</div>'
               '<div style="display:flex;gap:27px">'
               f'<div class="btn sec sm" style="flex:1;gap:14px;padding:0 10px">{PERSON}<div style="text-align:left;min-width:0"><div style="font:700 34px/38px Cinzel;letter-spacing:.06em">KARAKTERLER</div><div style="font:600 26px/30px Inter;letter-spacing:0;text-transform:none;color:#CFC4AE">{sel}</div></div></div>'
               f'<div class="btn sec sm" style="flex:1;gap:14px;padding:0 10px">{STAR}<div style="text-align:left;min-width:0"><div style="font:700 34px/38px Cinzel;letter-spacing:.06em">BAŞARIMLAR</div><div style="font:600 26px/30px Inter;letter-spacing:0;text-transform:none;color:#CFC4AE">{ach}</div></div></div></div>'
               '<div style="display:flex;gap:27px">'
               f'<div class="btn sec sm" style="flex:1;gap:14px;font-size:34px;letter-spacing:.06em;padding:0 10px">{TROPHY}EN İYİ SKORLAR</div>'
               f'<div class="btn sec sm" style="flex:1;gap:14px;font-size:34px;letter-spacing:.06em;padding:0 10px">{GEAR}AYARLAR</div></div>')
    else:  # 2x yazı: tek sütun
        top, hero_h, hero_top = 1301, 700, 520
        def r(ic, t, s=""):
            sub = f'<div style="font:600 52px/56px Inter;letter-spacing:0;text-transform:none;color:#CFC4AE">{s}</div>' if s else ""
            return f'<div class="btn sec" style="height:168px;gap:22px;font-size:56px;letter-spacing:.04em;justify-content:flex-start;padding:0 30px">{ic}<div style="text-align:left"><div style="line-height:60px">{t}</div>{sub}</div></div>'
        col = ('<div class="btn" style="height:180px;font-size:80px;letter-spacing:.14em">OYNA</div>'
               + r(PERSON, "KARAKTERLER") + r(STAR, "BAŞARIMLAR") + r(TROPHY, "EN İYİ SKORLAR") + r(GEAR, "AYARLAR"))
    b = BG.replace("#171020", "#0D0910")
    b += f'<div class="abs" style="left:60px;top:{hero_top}px;width:960px;height:{hero_h}px"><img src="{HERO}" alt="" style="width:100%;height:100%;object-fit:contain"></div>'
    b += '<div class="abs" style="left:0;right:0;top:0;height:560px;background:linear-gradient(180deg,#0D0910 25%,transparent)"></div>'
    b += '<div class="abs" style="left:0;right:0;top:150px;text-align:center"><div class="disp" style="font-size:36px;letter-spacing:.5em;color:#D2B47E;margin-bottom:12px">ASH AND STEEL</div><div class="title" style="font-size:132px;line-height:1.02">ASHEN<br>BASTION</div></div>'
    b += f'<div class="abs" style="left:0;right:0;top:{top-80}px;bottom:0;background:linear-gradient(0deg,#0D0910 70%,transparent)"></div>'
    b += f'<div class="abs" style="left:72px;right:72px;top:{top}px;display:flex;flex-direction:column;gap:27px">{col}</div>'
    b += f'<div class="abs" style="left:0;right:0;top:2288px;height:40px;text-align:center;font:600 26px/40px Inter;color:#A39883">Sürüm 2.0.3 · {sel}</div>'
    if anat:
        b += (call(72,1763,936,180,"OYNA 936×180 · y1763")+call(72,1970,454,132,"KARAKTERLER 454×132 · y1970")+call(554,1970,454,132,"BAŞARIMLAR 454×132")
              +call(72,2129,454,132,"EN İYİ SKORLAR 454×132 · y2129")+call(554,2129,454,132,"AYARLAR 454×132 (sütunda, köşede değil)")
              +call(72,2288,936,40,"sürüm · alt güvenli sınır y2328")+call(60,560,960,1100,"ana görsel 960×1100 · y560–1660 (aynı resim)",True))
    page(name, "Ana sayfa", b, "Ana sayfa")

# ============================================================ 02 Ayarlar
def sw(on, label=None):
    return f'<div class="sw {"on" if on else "off"}"><em>{label or ("AÇIK" if on else "KAPALI")}</em><i></i></div>'
def slider(lbl, pct, mute):
    return (f'<div style="padding-top:18px"><div class="rw" style="min-height:64px;border:0"><div class="tx"><div class="lb">{lbl}</div></div><div class="vl" style="{"color:#A39883" if mute else ""}">%{pct}</div></div>'
            f'<div class="sl{" mute" if mute else ""}"><div class="rail"><div class="fill" style="width:{pct}%"></div><div class="kn" style="left:{pct}%"></div></div></div></div>')
def settings(name="02-ayarlar", master=True, motion=False, vib=True, big=False, anat=False):
    mute = not master
    z = 2 if big else 1
    b = BG + '<div class="abs" style="left:0;right:0;top:130px;text-align:center;font:900 80px/90px Cinzel;color:#EFE7D6;letter-spacing:.06em;text-shadow:0 6px 0 #000">AYARLAR</div>'
    y = 260
    def sec(t, h):
        nonlocal y
        s = f'<div class="sec-h" style="top:{y}px">{t}</div>'; y += 84; return s
    def card(inner, h):
        nonlocal y
        s = f'<div class="card" style="top:{y}px;height:{h}px;display:flex;flex-direction:column;justify-content:center">{inner}</div>'; y += h + 36; return s
    if not big:
        b += sec("SES", 0)
        note = '<div class="ds" style="padding:6px 0 0;color:#CFC4AE;font-weight:600;font-size:26px">Ses kapalı. Bir kaydırıcıya dokunmak sesi açar.</div>' if mute else ''
        b += card(f'<div class="rw"><div class="tx"><div class="lb">TÜM SESLER</div></div>{sw(master)}</div>{note}{slider("MÜZİK", 70, mute)}{slider("EFEKT", 85, mute)}', 560 + (40 if mute else 0))
        b += sec("DOKUNUŞ", 0)
        b += card(f'<div class="rw" style="padding:20px 0"><div class="tx"><div class="lb">TİTREŞİM</div><div class="ds">Doldurma ve vuruşlarda hafif titreşim.</div></div>{sw(vib)}</div>', 176)
        b += sec("GÖRÜNÜM", 0)
        b += card(f'<div class="rw" style="padding:20px 0"><div class="tx"><div class="lb">HAREKETİ AZALT</div><div class="ds">Karakter seçimindeki hareketli portreyi durdurur.</div></div>{sw(motion)}</div>', 226)
        b += sec("HAKKINDA", 0)
        b += card('<div class="rw"><div class="tx"><div class="lb">SÜRÜM</div></div><div class="vl" style="font:600 32px Inter">2.0.3</div></div><div class="rw" style="min-height:132px"><div class="tx"><div class="lb">LİSANSLAR</div><div class="ds">Yazı tipleri, ses ve müzik.</div></div><div class="chev">›</div></div>', 316)
        scroll_end = y
    else:
        b += '<div class="abs" style="left:0;right:0;top:0;height:2400px"></div>'
        b += sec("SES", 0)
        b += card('<div class="rw" style="min-height:168px"><div class="tx"><div class="lb" style="font-size:72px;line-height:80px">TÜM SESLER</div></div></div><div class="rw" style="min-height:168px"><div class="tx"><div style="display:flex;justify-content:flex-end">'+sw(True)+'</div></div></div>'
                  '<div style="padding-top:18px"><div class="rw" style="min-height:96px;border:0"><div class="tx"><div class="lb" style="font-size:72px;line-height:80px">MÜZİK</div></div><div class="vl" style="font-size:72px">%70</div></div><div class="sl"><div class="rail"><div class="fill" style="width:70%"></div><div class="kn" style="left:70%"></div></div></div></div>', 680)
        b += sec("DOKUNUŞ", 0)
        b += card('<div class="rw" style="min-height:168px;padding:20px 0;flex-wrap:wrap"><div class="tx" style="flex-basis:100%"><div class="lb" style="font-size:72px;line-height:80px">TİTREŞİM</div><div class="ds" style="font-size:56px;line-height:64px">Doldurma ve vuruşlarda hafif titreşim.</div></div>'+sw(True)+'</div>', 420)
        b += '<div class="abs" style="left:0;right:0;top:1800px;height:372px;background:linear-gradient(180deg,transparent,#171020)"></div>'
        b += '<div class="abs" style="right:36px;top:260px;width:8px;height:300px;border-radius:4px;background:#A88A5C"></div>'
        scroll_end = 2400
    b += '<div class="abs" style="left:0;right:0;top:2060px;height:112px;background:linear-gradient(180deg,transparent,#171020)"></div>' if not big else ''
    b += '<div class="abs" style="left:72px;right:72px;top:2196px"><div class="btn sec sm" style="height:132px">GERİ</div></div>'
    if anat:
        b += (call(72,260,936,72,"bölüm başlığı 936×72 (bronz_300)")+call(72,344,936,560,"SES kartı: anahtar 132 · kaydırıcı 132 · aralık ≥27")
              +call(72,1054,936,176,"TİTREŞİM: satır tümüyle dokunur (≥132)")+call(72,2196,936,132,"GERİ · y2196 · alt güvenli 72")
              +call(72,1748,936,316,"HAKKINDA")+call(0,2070,1080,100,"alt solma · liste y260–2172 kaydırılır",True))
    page(name, "Ayarlar", b, "Ayarlar")

def lisans():
    items = [("CINZEL", "Yazı tipi · SIL Open Font License 1.1"), ("INTER", "Yazı tipi · SIL Open Font License 1.1"), ("SES VE MÜZİK", "Kaynaklar ve lisanslar LICENSES-audio.md")]
    rows = "".join(f'<div class="rw" style="padding:18px 0"><div class="tx"><div class="lb">{a}</div><div class="ds">{c}</div></div></div>' for a, c in items)
    b = BG + '<div class="abs" style="left:0;right:0;top:130px;text-align:center;font:900 80px/90px Cinzel;color:#EFE7D6;letter-spacing:.06em;text-shadow:0 6px 0 #000">LİSANSLAR</div>'
    b += f'<div class="card" style="top:300px;height:480px;display:flex;flex-direction:column;justify-content:center">{rows}</div>'
    b += '<div class="abs" style="left:72px;right:72px;top:2196px"><div class="btn sec sm">GERİ</div></div>'
    page("02d-lisanslar", "Lisanslar", b, "Lisanslar")

# ============================================================ 03 Başarımlar
TC = {0: "#4A3830", 1: "#CFC4AE", 2: "#D2B47E", 3: "#E8A24A", 4: "#E8A24A"}
ROMAN = ["", "I", "II", "III", "IV"]
def pips(n, got, tc):
    return '<div class="pips" style="gap:8px">' + "".join(f'<i class="{"on" if k < got else ""}" style="border-color:{tc if k < got else "#7A6045"};{"background:"+tc if k < got else ""}"></i>' for k in range(n)) + '</div>'
def fam(y, nm, icon, n, got, val, tgt, desc, done=False, dt=""):
    tier = got if got else 0
    tc = "#E8A24A" if done else TC[min(tier, 4) if n == 4 else min(tier, 3)] if tier else "#4A3830"
    cls = "plate" + (" lk" if got == 0 else "") + (" t4" if (n == 4 and got == 4 and not done) else "")
    rn = f'<span class="rn">{ROMAN[got]}</span>' if got and not done else ""
    lock = LOCK if got == 0 else ""
    left = f'<div class="{cls}" style="--tc:{tc}"><img src="{ACH}{icon}.png" alt="">{rn}{lock}</div>'
    if done:
        right = f'<div class="rt"><span class="done">TAMAM</span><div style="font:600 26px Inter;color:#A39883;margin-top:8px">{dt}</div></div>'
        dd = "Tüm kademeler açıldı."
    else:
        def num(x):
            x = str(x)
            if ':' in x:
                m, sec = x.split(':'); return int(m) * 60 + int(sec)
            d = ''.join(c for c in x if c.isdigit()); return int(d or 0) * (60 if 'sa' in x else 1)
        pc = min(100, int(100 * num(val) / max(1, num(tgt))))
        right = f'<div class="rt"><div class="v">{val}/{tgt}</div><div class="bar"><i style="width:{pc}%"></i></div></div>'
        dd = desc
    return (f'<div class="card fam{" cmp" if done else ""}" style="top:{y}px;height:168px;padding:0 24px"><style></style>{left}<div class="mid"><div class="nm">{nm}</div>'
            f'<div class="pp">{pips(n, got, tc if got else "#7A6045")}<span>{("KADEME "+ROMAN[got]) if got and not done else ("0 / %d" % n if got == 0 else "")}</span></div><div class="dd">{dd}</div></div>{right}</div>')
def ghead(y, t, c, tot, amber=False):
    col = "#E8A24A" if amber else "#CFC4AE"
    return f'<div class="ghead" style="top:{y}px"><span>{t}</span><span class="ct" style="color:{col}">{c} / {tot}</span></div>'
def summary(opened, total, panel=None, amber=False):
    s = ('<div class="abs" style="left:0;right:0;top:130px;text-align:center;font:900 80px/90px Cinzel;color:#EFE7D6;letter-spacing:.06em;text-shadow:0 6px 0 #000">BAŞARIMLAR</div>'
         f'<div class="abs" style="left:72px;top:250px;font:700 56px/68px Cinzel;color:{"#E8A24A" if amber else "#EFE7D6"}">{opened} / {total}<span style="font:600 32px Inter;color:#CFC4AE;margin-left:14px">kademe</span></div>'
         f'<div class="abs" style="left:72px;right:72px;top:340px;height:20px;border-radius:10px;background:#171020;border:3px solid #7A6045;overflow:hidden"><i style="display:block;height:100%;width:{100*opened//total}%;background:linear-gradient(90deg,{"#E8A24A,#E8A24A" if amber else "#A88A5C,#D2B47E"})"></i></div>')
    return s
def ach(name="03-basarimlar", mode="default", anat=False):
    b = BG
    if mode == "default":
        b += summary(31, 53)
        y = 400
        b += ghead(y, "SAĞ KALIM", 5, 11); y += 84
        b += fam(y, "HAYATTA KALMA", "on_dakika", 4, 2, "13:32", "15:00", "Tek koşuda 15 dakika hayatta kal."); y += 180
        b += fam(y, "DOKUNULMAZ", "dokunulmaz", 3, 1, "4:01", "5:00", "Tek koşuda 5 dk hasar almadan kal."); y += 180
        b += fam(y, "NÖBET", "yerlesik", 3, 0, "40 dk", "1 sa", "Toplam 1 saat oyna."); y += 180
        b += ghead(y, "KIRIM", 7, 14); y += 84
        b += fam(y, "ÖLDÜRME", "kalabalik_kesici", 4, 2, "2.940", "5.000", "Toplam 5.000 düşman öldür."); y += 180
        b += fam(y, "KIRIM", "kirim", 4, 1, "812", "1.000", "Tek koşuda 1.000 düşman öldür."); y += 180
        b += fam(y, "ÜÇ ELİT", "uc_elit", 1, 1, 0, 0, "", done=True, dt="23.10.2026")
    elif mode == "empty":
        b += summary(0, 53)
        b += '<div class="card" style="top:400px;height:108px;display:flex;align-items:center;justify-content:center;font:600 32px Inter;color:#CFC4AE;border-color:#7A6045">Henüz kademe açılmadı. Bir koşuya başla.</div>'
        y = 544
        b += ghead(y, "SAĞ KALIM", 0, 11); y += 84
        b += fam(y, "HAYATTA KALMA", "on_dakika", 4, 0, 0, 300, "Tek koşuda 5 dakika hayatta kal."); y += 180
        b += fam(y, "DOKUNULMAZ", "dokunulmaz", 3, 0, 0, 180, "Tek koşuda 3 dk hasar almadan kal."); y += 180
        b += ghead(y, "KIRIM", 0, 14); y += 84
        b += fam(y, "ÖLDÜRME", "kalabalik_kesici", 4, 0, 0, 100, "Toplam 100 düşman öldür."); y += 180
    elif mode == "all":
        b += summary(53, 53, amber=True)
        b += '<div class="card" style="top:400px;height:108px;display:flex;align-items:center;justify-content:center;font:600 32px Inter;color:#E8A24A;border-color:#E8A24A">Tüm başarımlar açıldı.</div>'
        y = 544
        b += ghead(y, "SAĞ KALIM", 11, 11, True); y += 84
        for nm, ic, n in (("HAYATTA KALMA", "on_dakika", 4), ("DOKUNULMAZ", "dokunulmaz", 3), ("NÖBET", "yerlesik", 3)):
            b += fam(y, nm, ic, n, n, 0, 0, "", done=True, dt="26.10.2026"); y += 180
    elif mode == "open":
        b += summary(31, 53)
        y = 400
        b += ghead(y, "KIRIM", 7, 14); y += 84
        b += fam(y, "ÖLDÜRME", "kalabalik_kesici", 4, 2, "2.940", "5.000", "Toplam 5.000 düşman öldür."); y += 168
        steps = [("I", "100", "✓ 12.10.2026", "#CFC4AE"), ("II", "1.000", "✓ 23.10.2026", "#D2B47E"), ("III", "5.000", "2.940 / 5.000", "#A39883"), ("IV", "25.000", "Hedef 25.000", "#A39883")]
        inner = "".join(f'<div class="step"><b style="color:{c}">{r}</b><span style="width:150px;color:#EFE7D6;font-family:Cinzel;font-weight:700;font-size:32px">{t}</span><span style="margin-left:auto;color:{"#CFC4AE" if "✓" in s else "#A39883"}">{s}</span></div>' for r, t, s, c in steps)
        b += f'<div class="card" style="top:{y-4}px;height:{72*4+30}px;border-top:0;border-radius:0 0 18px 18px;padding:12px 30px 0;background:#211832;left:96px;right:96px;border-color:#7A6045">{inner}<div style="position:absolute;left:30px;right:30px;top:{72*2+12+30}px;height:14px;border-radius:7px;background:#171020;border:3px solid #7A6045;display:none"></div></div>'
        y += 72 * 4 + 30 + 24
        b += fam(y, "KIRIM", "kirim", 4, 1, "812", "1.000", "Tek koşuda 1.000 düşman öldür.")
    b += '<div class="abs" style="left:72px;right:72px;top:2196px"><div class="btn sec sm">GERİ</div></div>'
    b += '<div class="abs" style="left:0;right:0;top:2092px;height:80px;background:linear-gradient(180deg,transparent,#171020)"></div>'
    if anat:
        b += (call(72,250,936,110,"özet: KADEME 31 / 53 (aile değil, kademe sayar)")+call(72,400,936,72,"grup başlığı 936×72 · aile sayısı değil tamamlanan kademe")
              +call(72,484,936,168,"aile satırı 936×168 · plaka 108 · ad 38 · rozet+baklava · sonraki hedef · değer/çubuk 232")
              +call(96,508,120,120,"kademe rengi + Romen",True)+call(72,2196,936,132,"GERİ y2196"))
    page(name, "Başarımlar", b, "Başarımlar")

# ============================================================ 04 Kademe dili
def tiers():
    b = BG + '<div class="abs" style="left:0;right:0;top:110px;text-align:center;font:900 64px Cinzel;color:#EFE7D6;letter-spacing:.06em">KADEME DİLİ</div>'
    cells = [("KİLİTLİ", 0, "#4A3830", False), ("I", 1, "#CFC4AE", False), ("II", 2, "#D2B47E", False), ("III", 3, "#E8A24A", False), ("IV", 4, "#E8A24A", False), ("TAMAM", 4, "#E8A24A", True)]
    for i, (lbl, g, tc, done) in enumerate(cells):
        x = 72 + (i % 3) * 320; y = 260 + (i // 3) * 360
        cls = "plate" + (" lk" if g == 0 else "") + (" t4" if lbl == "IV" else "")
        rn = f'<span class="rn">{lbl}</span>' if lbl in ("I", "II", "III", "IV") else ""
        n = 4
        b += (f'<div class="abs" style="left:{x}px;top:{y}px;width:296px;text-align:center"><div style="display:flex;justify-content:center"><div class="{cls}" style="--tc:{tc};width:144px;height:144px"><img style="width:92px;height:92px" src="{ACH}kirim.png" alt="">{rn}{LOCK if g==0 else ""}</div></div>'
              f'<div style="margin:30px 0 12px;display:flex;justify-content:center">{pips(n, 0 if g==0 else g, tc if g else "#7A6045")}</div>'
              f'<div style="font:700 28px Cinzel;color:{"#E8A24A" if done else "#D2B47E"};letter-spacing:.1em">{"✓ TAMAM" if done else lbl}</div></div>')
    b += '<div class="sec-h" style="top:1020px">KOŞU İÇİ BİLDİRİM</div>'
    b += ('<div class="abs" style="left:150px;top:1120px;width:780px;height:120px;border:4px solid #E8A24A;border-radius:18px;background:rgba(33,24,50,.94);box-shadow:0 0 30px rgba(232,162,74,.6);display:flex;align-items:center;gap:22px;padding:0 24px;box-sizing:border-box">'
          f'<div class="plate t4" style="--tc:#E8A24A;width:84px;height:84px"><img style="width:52px;height:52px" src="{ACH}kalabalik_kesici.png" alt=""></div>'
          '<div style="flex:1"><div style="font:700 26px Inter;letter-spacing:.14em;color:#D2B47E">BAŞARIM AÇILDI · KADEME III</div><div style="font:700 38px Cinzel;color:#EFE7D6">ÖLDÜRME III</div></div>'
          f'{pips(4,3,"#E8A24A")}</div>')
    b += '<div class="sec-h" style="top:1300px">SONUÇ ÖZETİ</div>'
    b += ('<div class="card" style="top:1390px;height:96px;border-color:#E8A24A;display:flex;align-items:center;gap:18px">'
          '<span style="font:700 30px Cinzel;color:#E8A24A">★ YENİ KADEME · 2</span><span style="font:600 28px Inter;color:#CFC4AE">Öldürme III, Hayatta Kalma II</span></div>')
    b += '<div class="sec-h" style="top:1540px">KURALLAR</div>'
    rules = ["Kademe = plaka çerçeve rengi + Romen rakamı + baklava sayısı; renk tek başına anlam taşımaz.",
             "Her kademede yeni ikon çizilmez: aile ikonu + çerçeve kullanılır (spec açık nokta 4).",
             "IV. kademe: bordo plaka + amber ışıma. Aile tamamlanınca Romen rakamı yerine TAMAM çipi.",
             "Çoklu eşik aynı anda aşılırsa tek bildirim, en yüksek kademe."]
    b += '<div class="card" style="top:1624px;height:440px;padding:24px 30px;display:flex;flex-direction:column;justify-content:center;gap:12px">' + "".join(f'<div style="font:400 30px/38px Inter;color:#EFE7D6">• {r}</div>' for r in rules) + '</div>'
    page("04-kademe-dili", "Kademe dili", b, "Kademe dili")

# ============================================================ 05 Küre brifi
def orbs():
    sv = ('<svg width="0" height="0" style="position:absolute"><defs>'
          '<filter id="pro"><feColorMatrix type="matrix" values=".152 1.053 -.205 0 0  .115 .786 .099 0 0  -.004 -.048 1.052 0 0  0 0 0 1 0"/></filter>'
          '<filter id="deu"><feColorMatrix type="matrix" values=".367 .861 -.228 0 0  .280 .673 .047 0 0  -.012 .043 .969 0 0  0 0 0 1 0"/></filter>'
          '<filter id="tri"><feColorMatrix type="matrix" values="1.256 -.077 -.179 0 0  -.078 .931 .148 0 0  .005 .691 .304 0 0  0 0 0 1 0"/></filter>'
          '<filter id="gry"><feColorMatrix type="saturate" values="0"/></filter></defs></svg>')
    b = BG + sv + '<div class="abs" style="left:0;right:0;top:100px;text-align:center;font:900 60px Cinzel;color:#EFE7D6;letter-spacing:.06em">RUH KÜRELERİ</div>'
    names = [("normal", "NORMAL", "xp < 5", "#BFE6F2"), ("elit", "ELİT", "5 ≤ xp < 80", "#A24ED0"), ("ara_boss", "ARA BOSS", "xp ≥ 80", "#E8A24A")]
    szs = {"normal": 330, "elit": 380, "ara_boss": 420}
    for i, (f, t, e, c) in enumerate(names):
        x = 72 + i * 320
        b += f'<div class="abs" style="left:{x}px;top:230px;width:296px;height:300px;border:3px solid #4A3830;border-radius:18px;background:#0D0910;display:flex;align-items:center;justify-content:center"><img src="{ORB}{f}.png" style="width:{int(szs[f]*.78)}px" alt=""></div>'
        b += f'<div class="abs" style="left:{x}px;top:548px;width:296px;text-align:center"><div style="font:700 32px Cinzel;color:{c};letter-spacing:.1em">{t}</div><div style="font:600 26px Inter;color:#CFC4AE">{e}</div></div>'
    b += '<div class="sec-h" style="top:660px">OYUN ÖLÇEĞİ (34 / 48 / 68 px) · ZEMİN ÜSTÜNDE</div>'
    b += '<div class="abs ground" style="left:72px;top:750px;width:936px;height:300px;border-radius:18px;border:4px solid #7A6045;overflow:hidden"></div>'
    pos = [(110, 140, "normal"), (210, 90, "normal"), (300, 170, "normal"), (392, 110, "normal"), (470, 60, "elit"), (560, 160, "elit"), (700, 90, "ara_boss"), (830, 150, "normal"), (900, 70, "normal")]
    ps = {"normal": 34 * 2, "elit": 48 * 2, "ara_boss": 68 * 2}
    for x, y, f in pos:
        s = ps[f]; b += f'<img class="abs" src="{ORB}{f}.png" style="left:{72+x-s//2}px;top:{750+y-s//2}px;width:{s}px" alt="">'
    b += '<div class="abs" style="left:84px;top:1012px;font:600 24px Inter;color:#A39883">gösterim ×2 büyütülmüş; gerçek ekranda 34 / 48 / 68 px</div>'
    b += '<div class="sec-h" style="top:1090px">RENK KÖRLÜĞÜ SİMÜLASYONU (YAKLAŞIK)</div>'
    for r, (flt, lbl) in enumerate([("none", "NORMAL"), ("url(#pro)", "PROTAN"), ("url(#deu)", "DEUTAN"), ("url(#tri)", "TRITAN"), ("url(#gry)", "GRİ")]):
        y = 1180 + r * 150
        b += f'<div class="abs" style="left:72px;top:{y+44}px;width:150px;font:700 26px Inter;color:#D2B47E;letter-spacing:.08em">{lbl}</div>'
        for i, f in enumerate(("normal", "elit", "ara_boss")):
            s = {"normal": 68, "elit": 96, "ara_boss": 136}[f]
            b += f'<div class="abs" style="left:{250+i*260}px;top:{y+75-s//2-8}px;width:240px;display:flex;justify-content:center"><img src="{ORB}{f}.png" style="width:{s}px;filter:{flt}" alt=""></div>'
    b += '<div class="sec-h" style="top:1940px">ÖLÇÜM (128 px, opak çekirdek)</div>'
    rows = [("", "L* normal", "protan", "deutan", "tritan", "alan"), ("NORMAL", "79,0", "80,4", "78,0", "79,1", "%11"), ("ELİT", "36,2", "36,9", "38,0", "37,4", "%25"), ("ARA BOSS", "74,1", "70,6", "76,0", "73,1", "%23")]
    t = "".join('<div style="display:flex;height:48px;align-items:center;font:600 26px Inter;color:#EFE7D6">' + "".join(f'<span style="width:{190 if i==0 else 150}px;{"font-weight:700;color:#D2B47E" if i==0 or ri==0 else ""}">{c}</span>' for i, c in enumerate(r)) + '</div>' for ri, r in enumerate(rows))
    b += f'<div class="card" style="top:2028px;height:230px;padding:14px 30px;display:flex;flex-direction:column;justify-content:center">{t}</div>'
    b += '<div class="abs" style="left:72px;top:2272px;font:600 26px/32px Inter;color:#CFC4AE;width:936px">Silüet IoU: normal–elit 0,37 · normal–boss 0,46 · elit–boss 0,51 (≤0,6 ✓). L* farkı normal–boss yalnız 4,9 → ayrım boyut (1:2) + taç silüeti.</div>'
    page("05-kure-gorsel-yonu", "Küre yönü", b, "Küre görsel yönü")

menu(); menu("01b-ana-sayfa-anatomi", anat=True); menu("01c-ana-sayfa-ilk-acilis", ach="0/53"); menu("01d-ana-sayfa-yazi-2x", big=True)
settings(); settings("02a-ayarlar-anatomi", anat=True); settings("02b-ayarlar-sessiz-hareket-azalt", master=False, motion=True, vib=False); settings("02c-ayarlar-yazi-2x", big=True); lisans()
ach(); ach("03a-basarimlar-anatomi", anat=True); ach("03b-basarimlar-bos", "empty"); ach("03c-basarimlar-hepsi-acik", "all"); ach("03d-basarimlar-satir-acik", "open")
tiers(); orbs()
