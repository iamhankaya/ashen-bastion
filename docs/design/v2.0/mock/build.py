#!/usr/bin/env python3
"""v2.0 maketlerini üretir (statik HTML, 1080x2400). Çalıştır: python3 build.py && node shoot.js"""
import re, pathlib
HERE = pathlib.Path(__file__).parent
R = "../../../../"            # repo kökü
ICON = R + "assets/ui/icons/"
FR = R + "art/ui/frames/"
PORTRAIT = R + "art/ref/portre-seviye-atlama.png"
HERO = "../../../ui/mockups/assets/gunslinger-atis-keyed.png"
PH = "filter:sepia(.55) hue-rotate(-18deg) saturate(.75) brightness(.92)"   # yer tutucu tonu (Barutçu)

def page(name, title, body, aria):
    html = ('<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=1080">'
            f'<title>{title} — Ashen Bastion v2.0 maketi</title><link rel="stylesheet" href="mock.css"><style>body{{height:2400px}}</style></head>'
            f'<body><main class="screen" style="height:2400px" aria-label="{aria}">{body}</main></body></html>')
    (HERE / f"{name}.html").write_text(html, encoding="utf-8")

def call(x, y, w, h, label, inside=False):
    return f'<div class="call" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"><b class="{"in" if inside else ""}">{label}</b></div>'

LOCK = '<svg width="{s}" height="{s}" viewBox="0 0 48 48"><path d="M14 22V16a10 10 0 0 1 20 0v6" fill="none" stroke="{c}" stroke-width="5"/><rect x="9" y="22" width="30" height="22" rx="4" fill="{c}" stroke="#2B0E14" stroke-width="3"/><rect x="21" y="30" width="6" height="8" rx="2" fill="#2B0E14"/></svg>'
CHECK = '<svg width="{s}" height="{s}" viewBox="0 0 48 48"><circle cx="24" cy="24" r="21" fill="{bg}" stroke="{c}" stroke-width="4"/><path d="M13 25l8 8 14-17" fill="none" stroke="{c}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/></svg>'
PERSON = '<svg width="52" height="52" viewBox="0 0 52 52"><circle cx="26" cy="16" r="9" fill="#D2B47E" stroke="#2B0E14" stroke-width="3"/><path d="M8 46c0-11 8-18 18-18s18 7 18 18z" fill="#D2B47E" stroke="#2B0E14" stroke-width="3"/><path d="M20 30l6 8 6-8" fill="none" stroke="#A88A5C" stroke-width="4"/></svg>'
STAR = '<svg width="52" height="52" viewBox="0 0 52 52"><path d="M26 4l6.5 14.5 15.5 1.7-11.6 10.6 3.3 15.7L26 38.6 12.3 46.5l3.3-15.7L4 20.2l15.5-1.7z" fill="#D2B47E" stroke="#2B0E14" stroke-width="3" stroke-linejoin="round"/></svg>'
TROPHY = '<svg width="52" height="52" viewBox="0 0 52 52"><path d="M14 6H38V22C38 30 32 35 26 35C20 35 14 30 14 22Z" fill="#D2B47E" stroke="#2B0E14" stroke-width="3"/><path d="M14 10H6C6 20 10 24 15 25M38 10H46C46 20 42 24 37 25" fill="none" stroke="#D2B47E" stroke-width="4"/><rect x="22" y="35" width="8" height="8" fill="#A88A5C" stroke="#2B0E14" stroke-width="3"/><rect x="14" y="43" width="24" height="6" rx="2" fill="#7A6045" stroke="#2B0E14" stroke-width="3"/></svg>'

# ------------------------------------------------------------------ 01 Ana menü
def menu(sel_name="Barutçu", ach="8/22", anat=False, name="01-ana-menu"):
    b = ('<div class="abs" style="inset:0;background:radial-gradient(ellipse 80% 50% at 50% 40%,rgba(92,29,38,.55),transparent 70%),linear-gradient(180deg,#0D0910,#171020 60%,#0D0910)"></div>'
         f'<div class="abs" style="left:60px;top:560px;width:960px;height:960px"><img src="{HERO}" alt="" style="width:100%;height:100%;object-fit:contain"></div>'
         '<div class="abs" style="left:0;right:0;top:0;height:560px;background:linear-gradient(180deg,#0D0910 25%,transparent)"></div>'
         '<div class="abs" style="left:0;right:0;top:150px;text-align:center"><div class="disp" style="font-size:36px;letter-spacing:.5em;color:#D2B47E;margin-bottom:12px">ASH AND STEEL</div><div class="title" style="font-size:132px;line-height:1.02">ASHEN<br>BASTION</div></div>'
         '<div class="abs" style="left:0;right:0;top:1470px;height:930px;background:linear-gradient(0deg,#0D0910 62%,transparent)"></div>'
         '<div class="abs" style="left:72px;right:72px;top:1556px;display:flex;flex-direction:column;gap:27px">'
         '<div class="btn" style="height:180px;font-size:64px;letter-spacing:.14em">OYNA</div>'
         '<div style="display:flex;gap:27px">'
         f'<div class="btn sec sm" style="flex:1;gap:14px;padding:0 10px">{PERSON}<div style="text-align:left;min-width:0"><div style="font:700 34px/38px Cinzel;letter-spacing:.06em">KARAKTERLER</div><div style="font:600 26px/30px Inter;letter-spacing:0;text-transform:none;color:#CFC4AE">{sel_name}</div></div></div>'
         f'<div class="btn sec sm" style="flex:1;gap:14px;padding:0 10px">{STAR}<div style="text-align:left;min-width:0"><div style="font:700 34px/38px Cinzel;letter-spacing:.06em">BAŞARIMLAR</div><div style="font:600 26px/30px Inter;letter-spacing:0;text-transform:none;color:#CFC4AE">{ach}</div></div></div></div>'
         f'<div class="btn sec sm">{TROPHY}EN İYİ SKORLAR</div>'
         '<div style="display:flex;gap:27px"><div class="btn sec sm" style="flex:1">SES: AÇIK</div><div class="btn sec sm" style="flex:1">TİTREŞİM: AÇIK</div></div>'
         f'<div style="text-align:center;font:600 26px Inter;color:#A39883;height:40px">Sürüm 2.0 · {sel_name}</div></div>')
    if anat:
        b += (call(72,1556,936,180,"OYNA 936×180 (değişmedi) y1556")+call(72,1763,454,132,"KARAKTERLER 454×132 · y1763")+call(554,1763,454,132,"BAŞARIMLAR 454×132")
              +call(72,1922,936,132,"EN İYİ SKORLAR 936×132 · y1922")+call(72,2081,936,132,"SES / TİTREŞİM · y2081")+call(60,560,960,960,"ana görsel 960×960 · y560–1520",True))
    page(name, "Ana menü", b, "Ana menü — Karakterler ve Başarımlar girişi")

# ------------------------------------------------------------------ 02 Karakterler
CH = {
 "gunslinger": dict(ad="GUNSLINGER", blurb="Çift tabancalı, çevik ve hızlı. Şarjörü boşalmadan kalabalığı yarar.", skill="Çift Tabanca", icon="cift-tabanca",
                    st=[("CAN","100"),("HIZ","300"),("ŞARJÖR","6"),("DOLDURMA","1,0 sn"),("MENZİL","700"),("TOPLAMA","110")], ph=False),
 "barutcu":    dict(ad="BARUTÇU", blurb="Yavaş ve dayanıklı. Fitilini yaktığı dinamitlerle kalabalığı daha yaklaşmadan dağıtır.", skill="Dinamit", icon="dinamit",
                    st=[("CAN","120"),("HIZ","270"),("ŞARJÖR","5"),("DOLDURMA","1,2 sn"),("MENZİL","650"),("TOPLAMA","120")], ph=True),
}
def chars(focus="barutcu", selected="gunslinger", locked=False, anat=False, name="02-karakterler", single=False):
    c = CH[focus]; f = PH if c["ph"] else ""
    stage_f = f + (";filter:grayscale(1) brightness(.55)" if locked else "")
    if locked: stage_f = "filter:grayscale(1) brightness(.5)"
    b = '<div class="abs" style="inset:0;background:#0D0910"></div>'
    b += f'<div class="abs" style="left:0;top:190px;width:1080px;height:1060px;overflow:hidden"><img src="{PORTRAIT}" alt="" style="width:1080px;height:1620px;object-fit:cover;object-position:50% 0;{stage_f}"></div>'
    b += '<div class="abs" style="left:0;top:190px;width:1080px;height:1060px;background:linear-gradient(0deg,#0D0910 2%,rgba(13,9,16,.9) 24%,rgba(13,9,16,.35) 52%,transparent 74%)"></div>'
    b += '<div class="abs" style="left:0;top:96px;width:1080px;height:190px;background:linear-gradient(180deg,#0D0910 30%,transparent)"></div>'
    if locked:
        b += f'<div class="abs" style="left:420px;top:560px;width:240px;height:240px;border-radius:50%;background:rgba(13,9,16,.7);border:6px solid #A88A5C;display:flex;align-items:center;justify-content:center">{LOCK.format(s=130,c="#D2B47E")}</div>'
    cnt = "" if single else '<div style="position:absolute;right:72px;top:126px;font:700 28px Inter;color:#D2B47E;letter-spacing:.1em">2 / 2</div>'
    b += f'<div class="abs" style="left:72px;top:112px;font:900 64px Cinzel;letter-spacing:.08em;text-shadow:0 5px 0 #000">KARAKTERLER</div>{cnt}'
    chip = ""
    if focus == selected: chip = '<span class="tag w">✓ SEÇİLİ</span>'
    elif locked: chip = f'<span class="tag b" style="gap:8px">{LOCK.format(s=24,c="#D2B47E")} KİLİTLİ</span>'
    b += f'<div class="abs" style="left:72px;right:72px;top:1060px"><div style="display:flex;align-items:center;gap:24px"><div style="font:900 96px/100px Cinzel;letter-spacing:.06em;text-shadow:0 6px 0 #000,0 0 40px rgba(143,42,54,.6)">{c["ad"]}</div>{chip}</div></div>'
    # panel
    stats = "".join(f'<div style="width:282px;height:78px;border-radius:12px;background:rgba(13,9,16,.45);padding:6px 18px"><div style="font:700 26px/30px Inter;letter-spacing:.08em;color:#CFC4AE">{k}</div><div style="font:700 40px/40px Cinzel;color:#EFE7D6">{v}</div></div>' for k, v in c["st"])
    b += ('<div class="abs panel" style="left:72px;right:72px;top:1250px;height:446px;padding:24px 27px">'
          f'<div style="font:400 32px/42px Inter;color:#EFE7D6;height:84px;overflow:hidden">{c["blurb"]}</div>'
          f'<div style="display:flex;align-items:center;gap:18px;height:84px;margin-top:18px"><div style="position:relative;width:84px;height:84px;flex:none"><img src="{FR}cerceve-aktif.svg" style="position:absolute;inset:0;width:84px;height:84px" alt=""><img src="{ICON}{c["icon"]}.svg" style="position:absolute;left:14px;top:14px;width:56px;height:56px" alt=""></div>'
          f'<div><div style="font:700 26px/30px Inter;letter-spacing:.08em;color:#D2B47E">BAŞLANGIÇ BECERİSİ</div><div style="font:700 38px/44px Cinzel">{c["skill"].upper().replace("İ","İ")}</div></div></div>'
          f'<div style="display:flex;flex-wrap:wrap;gap:12px;margin-top:18px">{stats}</div></div>')
    # strip
    if not single:
        def card(key, nm, foc, sel, lk, ph):
            fl = "filter:grayscale(1) brightness(.5);" if lk else (PH + ";" if ph else "")
            bd = "border:6px solid #D2B47E;box-shadow:0 0 30px rgba(232,162,74,.5);" if foc else "border:4px solid #7A6045;"
            badge = ""
            if sel: badge = f'<div style="position:absolute;right:-10px;top:-10px">{CHECK.format(s=56,c="#2B0E14",bg="#E8A24A")}</div>'
            if lk: badge = f'<div style="position:absolute;right:-6px;top:-6px;width:56px;height:56px;border-radius:50%;background:#0D0910;border:4px solid #A88A5C;display:flex;align-items:center;justify-content:center">{LOCK.format(s=30,c="#D2B47E")}</div>'
            return (f'<div style="position:relative;width:252px;height:264px;border-radius:18px;{bd}background:#171020"><div style="position:absolute;inset:0;border-radius:12px;overflow:hidden"><img src="{PORTRAIT}" alt="" style="width:100%;height:100%;object-fit:cover;object-position:60% 22%;{fl}"></div>'
                    f'<div style="position:absolute;left:0;right:0;bottom:0;height:78px;border-radius:0 0 12px 12px;background:linear-gradient(0deg,rgba(13,9,16,.95) 40%,transparent);display:flex;align-items:flex-end;justify-content:center;padding-bottom:8px;font:700 28px Cinzel;letter-spacing:.06em">{nm}</div>{badge}</div>')
        cards = card("g","GUNSLINGER",focus=="gunslinger",selected=="gunslinger",False,False)+card("b","BARUTÇU",focus=="barutcu",selected=="barutcu",locked,True)
        b += f'<div class="abs" style="left:0;right:0;top:1722px;display:flex;justify-content:center;gap:27px">{cards}</div>'
    # buton
    if locked:
        btn = '<div class="btn dis" style="flex-direction:column;gap:2px;height:156px;font-size:40px">KİLİTLİ<div class="sub" style="color:#CFC4AE">“Beş Dakika” başarımını aç</div></div>'
    elif focus == selected:
        btn = '<div class="btn sel" style="height:156px;font-size:48px">✓ SEÇİLİ</div>'
    else:
        btn = '<div class="btn" style="height:156px;font-size:52px">SEÇ</div>'
    b += f'<div class="abs" style="left:72px;right:72px;top:2013px;display:flex;flex-direction:column;gap:27px">{btn}<div class="btn sec sm" style="height:132px">GERİ</div></div>'
    if anat:
        b += (call(0,190,1080,1060,"vitrin sahnesi · portre tam-taşma · y190–1250 · nefes/sürüklenme")+call(72,1060,700,110,"ad 96 px · upper_tr · y1060",True)+call(72,1250,936,446,"bilgi paneli 936×446 (içerik büyürse sahne kısalır)")
              +call(274,1722,531,264,"kart 252×264 · aralık 27 · yatay kaydırma")+call(72,2013,936,156,"SEÇ / SEÇİLİ / KİLİTLİ 936×156")+call(72,2196,936,132,"GERİ 936×132 · alt 72")+call(72,112,520,80,"başlık y112 (güvenli üst 96)"))
    page(name, "Karakterler", b, "Karakterler vitrini")

# ------------------------------------------------------------------ 03 Başarımlar
TIERS = {"kolay":1,"orta":2,"zor":3,"çok zor":4}
def pips(n): return '<div class="pips">'+"".join(f'<i class="{"on" if i<n else ""}"></i>' for i in range(4))+'</div>'
def up(t): return t.replace("i","İ").replace("ı","I").upper()
def arow(y, nm, ds, ic, kind, tier, val=None, date=None, runonly=None):
    fr = "cerceve-aktif" if kind=="open" else "cerceve-pasif"
    cls = "arow panel" + (" locked" if kind!="open" else "")
    bd = {"kolay":"#7A6045","orta":"#7A6045","zor":"#A88A5C","çok zor":"#E8A24A"}[tier]
    sty = f"top:{y}px;border-color:{bd if kind=='open' else '#4A3830'};" + ("box-shadow:0 0 24px rgba(232,162,74,.4),0 12px 36px rgba(0,0,0,.7);" if kind=="open" and tier=="çok zor" else "")
    if kind=="open":
        rt = f'<div style="display:flex;justify-content:flex-end">{CHECK.format(s=44,c="#2B0E14",bg="#8DB58A")}</div><div class="dt">{date}</div>'
    elif runonly:
        rt = f'<div class="tag b" style="height:36px;font-size:26px;letter-spacing:.04em">TEK KOŞU</div><div class="dt" style="color:#CFC4AE">Hedef {runonly}</div>'
    else:
        a, t = val; pct = min(100, round(100*a/t))
        rt = f'<div class="v">{a:,}/{t:,}</div><div class="bar"><i style="width:{pct}%"></i></div>'.replace(",",".")
    lock = '' if kind=="open" else f'<div style="position:absolute;right:-4px;bottom:-4px;width:40px;height:40px;border-radius:50%;background:#0D0910;border:3px solid #A88A5C;display:flex;align-items:center;justify-content:center">{LOCK.format(s=22,c="#D2B47E")}</div>'
    return (f'<div class="{cls}" style="{sty}"><div class="plate"><img class="fr" src="{FR}{fr}.svg" alt=""><img class="ic" src="{ICON}{ic}.svg" alt="">{lock}</div>'
            f'<div class="mid"><div class="nm">{up(nm)}</div><div class="ds">{ds}</div></div><div class="rt">{rt}</div></div>')

def ghead(y, nm, n, got, tot): return f'<div class="ghead" style="top:{y}px">{nm}{pips(n)}<span class="ct">{got} / {tot}</span></div>'

def ach(empty=False, anat=False, name="03-basarimlar"):
    got = 0 if empty else 8
    b = '<div class="abs" style="inset:0;background:radial-gradient(ellipse 80% 40% at 50% 0%,rgba(92,29,38,.45),transparent 70%),#171020"></div>'
    b += ('<div class="abs" style="left:0;right:0;top:130px;text-align:center"><div class="title" style="font-size:80px">BAŞARIMLAR</div></div>'
          f'<div class="abs" style="left:72px;right:72px;top:262px;display:flex;align-items:baseline;gap:14px"><span style="font:700 56px/60px Cinzel;color:#EFE7D6">{got} / 22</span><span style="font:600 32px Inter;color:#CFC4AE">açıldı</span></div>'
          f'<div class="abs" style="left:72px;right:72px;top:340px;height:20px;border-radius:10px;background:#0D0910;border:3px solid #7A6045;overflow:hidden"><i style="display:block;height:100%;width:{round(100*got/22)}%;background:linear-gradient(90deg,#A88A5C,#D2B47E)"></i></div>')
    top = 400
    if empty:
        b += '<div class="abs panel" style="left:72px;right:72px;top:400px;height:108px;display:flex;align-items:center;justify-content:center;font:600 32px Inter;color:#CFC4AE;border-color:#7A6045">Henüz açılan başarım yok. Bir koşuya başla.</div>'
        top = 528
    O = lambda *a, **k: "open"
    rows = [
      ("İlk Kan","Bir düşmanı öldür.","hud-oldurme","open",None,"23.10.2026",None),
      ("Beş Dakika","Tek koşuda 300 sn hayatta kal.","hud-sure","open",None,"23.10.2026",None),
      ("Seviye 10","Tek koşuda 10. seviyeye ulaş.","hud-xp","open",None,"22.10.2026",None),
      ("Yerleşik","10 koşu oyna.","hud-duraklat","lock",(6,10),None,None),
      ("Tambur Ustası","Tek koşuda 100 kez doldur.","hud-mermi","lock",None,None,"100"),
      ("Tam Kadro","6 aktif yuvayı doldur.","cift-tabanca","lock",None,None,"6"),
    ]
    if empty:
        fix = {"İlk Kan":((0,1),None),"Beş Dakika":(None,"300 sn"),"Seviye 10":(None,"10"),"Yerleşik":((0,10),None)}
        rows = [(n,d,i,"lock",fix.get(n,(v,r))[0],None,fix.get(n,(v,r))[1]) for (n,d,i,k,v,dt,r) in rows]
    y = top
    b += ghead(y,"KOLAY",1,min(got,3),6); y += 84
    for (n,d,i,k,v,dt,r) in rows:
        b += arow(y,n,d,i,k,"kolay",val=v,date=dt,runonly=r if not v else None); y += 168
    b += ghead(y,"ORTA",2,0 if empty else 1,9); y += 84
    r2 = [("Kırım","Tek koşuda 500 düşman öldür.","hud-oldurme","lock",None,None,"500"),
          ("Kalabalık Kesici","Toplam 10.000 düşman öldür.","hud-oldurme","lock",(0 if empty else 3402,10000),None,None)]
    if not empty: r2.insert(0,("On Dakika","Tek koşuda 600 sn hayatta kal.","hud-sure","open",None,"23.10.2026",None)); r2=r2[:3]
    for (n,d,i,k,v,dt,r) in r2:
        b += arow(y,n,d,i,k,"orta",val=v,date=dt,runonly=r); y += 168
    b += '<div class="abs" style="left:0;right:0;top:2130px;height:80px;background:linear-gradient(0deg,#171020,transparent)"></div>'
    b += '<div class="abs" style="right:44px;top:420px;width:8px;height:340px;border-radius:4px;background:rgba(210,180,126,.55)"></div>'
    b += '<div class="abs" style="left:72px;right:72px;top:2196px"><div class="btn sec sm">GERİ</div></div>'
    if anat:
        b += (call(72,400,936,72,"grup başlığı 936×72 (yapışkan)")+call(72,484,936,156,"satır 936×156 · aralık 12 · adım 168")+call(96,508,108,108,"ikon plakası 108")+call(228,508,516,108,"ad 38 + açıklama ≤2 satır 28")+call(768,508,240,108,"sağ sütun 240: ilerleme/tarih")
              +call(72,2196,936,132,"GERİ 936×132 · alt 72")+call(1044,420,8,340,"kaydırma ipucu 8 px",True)+call(72,262,936,100,"özet: sayaç + çubuk 20 px"))
    page(name, "Başarımlar", b, "Başarımlar listesi")

# ------------------------------------------------------------------ 04 HUD bildirimi
def toast(y, nm="BEŞ DAKİKA", tier="kolay", ic="hud-sure"):
    glow = "box-shadow:0 0 30px rgba(232,162,74,.55),0 12px 36px rgba(0,0,0,.7);border-color:#E8A24A;" if tier in ("zor","çok zor") else "border-color:#A88A5C;"
    return (f'<div class="abs" style="left:150px;width:780px;top:{y}px;height:120px;border-radius:18px;border:4px solid;{glow}background:rgba(33,24,50,.94);display:flex;align-items:center;gap:24px;padding:0 24px;z-index:20">'
            f'<div style="position:relative;width:84px;height:84px;flex:none"><img src="{FR}cerceve-aktif.svg" style="position:absolute;inset:0;width:84px;height:84px" alt=""><img src="{ICON}{ic}.svg" style="position:absolute;left:14px;top:14px;width:56px;height:56px" alt=""></div>'
            f'<div style="flex:1;min-width:0"><div style="display:flex;align-items:center;justify-content:space-between"><div style="font:700 26px/30px Inter;letter-spacing:.14em;color:#D2B47E">BAŞARIM AÇILDI</div>{pips(TIERS[tier])}</div><div style="font:700 38px/48px Cinzel;color:#EFE7D6;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{nm}</div></div></div>')

def hud_toast(anat=False, name="04-hud-basarim-bildirimi"):
    s = (HERE / "../../v1.1/mock/01-hud-skor-eklenti.html").read_text(encoding="utf-8")
    body = re.search(r'<main[^>]*>(.*)</main>', s, re.S).group(1)
    body = body.replace('src="pickups/', 'src="../../v1.1/mock/pickups/')
    body = re.sub(r'<div class="(?:call|cap)[^>]*>.*?</div>(?=<)', lambda m: m.group(0) if 'cap' in m.group(0)[:20] else '', body) if False else body
    body += toast(820, "BEŞ DAKİKA", "kolay") 
    if anat:
        body += (call(150,820,780,120,"bildirim 780×120 · y820 + güvenli üst")+call(150,826,108,108,"ikon 84",True)
                 +call(560,284,484,152,"skor + SERİ y284–436")+call(36,2160,560,168,"tambur + rozetler")
                 +call(190,494,700,110,"elit/Lord satırı y494–604")+call(0,520,1080,132,"Lord bandı y520–652 (+üst pay)")+call(36,270,540,90,"yuvalar"))
    page(name, "HUD başarım bildirimi", f'<div style="position:absolute;inset:0">{body}</div>', "Koşu içi başarım bildirimi")

def toast_states():
    b = '<div class="abs" style="inset:0;background:#171020"></div>'
    b += '<div class="abs" style="left:72px;top:130px;font:900 64px Cinzel;letter-spacing:.06em">BİLDİRİM DURUMLARI</div>'
    items = [("BEŞ DAKİKA","kolay","hud-sure","kolay · bronz kenar · 1 baklava"),("ARA BOSS AVCISI","orta","hud-oldurme","orta · bronz kenar · 2 baklava"),
             ("SEVİYE 20","orta","hud-xp","orta"),("İLK EVRİM","zor","zincirleme-patlama","zor · amber kenar+ışıma · 3 baklava"),
             ("KALE LORDU DEVRİLDİ","çok zor","hud-can","çok zor · amber kenar+ışıma · 4 baklava · uzun ad (19 harf; sınır 22)")]
    y = 330
    for nm,t,ic,cap in items:
        b += f'<div class="abs" style="left:150px;top:{y-44}px;font:600 26px Inter;color:#A39883">{cap}</div>'+toast(y,nm,t,ic).replace('top:%dpx'%y,'top:%dpx'%y); y += 230
    b += ('<div class="abs panel" style="left:72px;right:72px;top:1530px;padding:24px 36px;font:400 30px/42px Inter;color:#CFC4AE"><div class="sec-t" style="font-size:30px;margin-bottom:8px">ZAMANLAMA</div>'
          'Giriş 220 ms (yukarıdan 24 px kayar + solma, cubic-out) · bekleme 2 100 ms · çıkış 180 ms = <b style="color:#EFE7D6">2 500 ms</b>.<br>Aynı anda en çok <b style="color:#EFE7D6">1</b> bildirim; kuyruk <b style="color:#EFE7D6">3</b>; taşan sessizce sonuç özetine gider.<br>Yanıp sönme yok (≤3 Hz kuralı). Ses yok. Dokunmayı yutmaz (<code>mouse_filter = IGNORE</code>).<br>Duraklatma / seviye atlama / onay açıkken sayaç durur, bildirim bekler.</div>')
    page("04b-bildirim-durumlari","Bildirim durumları",b,"Bildirim durumları ve zamanlama")

# ------------------------------------------------------------------ 05 Seviye atlama
def levelup(ad="GUNSLINGER", ph=False, noportrait=False, anat=False, name="05-seviye-atlama"):
    src = (HERE / "../../../ui/mockups/04-seviye-atlama.html").read_text(encoding="utf-8")
    cards = re.search(r'(<div class="panel abs" role="button".*?)<div class="abs" style="left:0;right:0;bottom:84px', src, re.S).group(1)
    cards = cards.replace('../../../art/', R+'art/')
    f = PH if ph else ""
    b = '<div class="abs" style="inset:0;background:#0D0910"></div>'
    if noportrait:
        b += '<div class="abs" style="left:0;top:0;width:1080px;height:1620px;background:radial-gradient(ellipse 90% 60% at 50% 45%,rgba(92,29,38,.55),transparent 75%),#0D0910"></div>'
    else:
        b += f'<div class="abs" style="left:0;top:0;width:1080px;height:1620px"><img src="{PORTRAIT}" alt="" style="width:100%;height:100%;object-fit:cover;{f}"></div>'
    b += '<div class="abs" style="left:0;top:0;width:1080px;height:1620px;background:linear-gradient(180deg,transparent 0,transparent 560px,rgba(13,9,16,.72) 860px,rgba(13,9,16,.9) 1000px,#0D0910 1150px)"></div>'
    b += ('<div class="abs" style="left:60px;top:880px"><div style="font:700 34px Cinzel;letter-spacing:.18em;color:#D2B47E;text-shadow:0 3px 0 #000">'+ad+'</div>'
          '<div class="title" style="text-align:left;font-size:104px;margin-top:8px">SEVİYE 4</div></div>')
    b += cards
    b += '<div class="abs" style="left:0;right:0;bottom:84px;text-align:center;font:600 28px Inter;color:#A39883">Bir karta dokun</div>'
    if anat:
        b += (call(60,880,520,170,"başlık bloğu y880–1050 (alt gradyan üstünde)")+call(0,0,1080,880,"portre serbest alan (başlık yok · namlu/yüz temiz)",True)+call(48,1090,984,324,"kartlar 984×324 · aralık 27 (kodda alt pay 200 → 3 kartta ilk kart y1174)"))
    page(name, "Seviye atlama", b, "Seviye atlama")

# ------------------------------------------------------------------ 06 Sonuç
def result(name="06-sonuc-yeni-basarim", anat=False):
    s = (HERE / "../../v1.1/mock/04-sonuc-skor-rekor.html").read_text(encoding="utf-8")
    body = re.search(r'<main[^>]*>(.*)</main>', s, re.S).group(1)
    body = body.replace("font:600 24px Inter;color:#A39883","font:600 26px Inter;color:#A39883")
    pill = (f'<div class="abs panel" style="left:72px;right:72px;top:1418px;height:96px;display:flex;align-items:center;gap:18px;padding:0 24px;border-color:#E8A24A">{STAR.replace("52","44")}'
            '<div style="font:700 30px Cinzel;letter-spacing:.08em;color:#E8A24A;white-space:nowrap">YENİ BAŞARIM · 2</div>'
            '<div style="font:600 28px Inter;color:#CFC4AE;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">İlk Kan, Beş Dakika</div></div>')
    body = body.replace('<div class="abs panel" style="left:72px;right:72px;top:1418px;padding:24px 36px">', pill+'<div class="abs panel" style="left:72px;right:72px;top:1538px;padding:24px 36px">')
    body = body.replace('top:1730px;display:flex','top:1866px;display:flex')
    if anat:
        body += call(72,1418,936,96,"yeni başarım özeti 936×96 · y1418")+call(72,1538,936,300,"kombolar en çok 3 satır (özet varken)")+call(72,1866,936,315,"düğmeler y1866 → 2181 (<2328)")
    page(name,"Sonuç — yeni başarım",f'<div style="position:absolute;inset:0">{body}</div>',"Sonuç ekranı, yeni başarım özeti")

def tokens_sheet():
    b = '<div class="abs" style="inset:0;background:#171020"></div><div class="abs" style="left:72px;top:130px;font:900 60px Cinzel;letter-spacing:.06em">YER TUTUCU STİLİ</div>'
    b += f'<div class="abs" style="left:72px;top:260px;width:456px"><img src="{PORTRAIT}" style="width:456px;height:684px;object-fit:cover;border-radius:18px;border:4px solid #7A6045" alt=""><div style="font:700 28px Inter;color:#D2B47E;margin-top:12px">Gunslinger (gerçek)</div></div>'
    b += f'<div class="abs" style="left:552px;top:260px;width:456px"><img src="{PORTRAIT}" style="width:456px;height:684px;object-fit:cover;border-radius:18px;border:4px solid #7A6045;{PH}" alt=""><div style="font:700 28px Inter;color:#D2B47E;margin-top:12px">Barutçu (yer tutucu: ton kaydırılmış)</div></div>'
    b += ('<div class="abs panel" style="left:72px;right:72px;top:1060px;padding:24px 36px;font:400 30px/42px Inter;color:#CFC4AE"><div class="sec-t" style="font-size:30px;margin-bottom:8px">KURAL</div>'
          'Görsel dosyası yoksa ya da <code>portrait</code> alanı boşsa: <b style="color:#EFE7D6">Gunslinger</b> dosyası kullanılır; shader: doygunluk ×0,75, sepya %55, ton −18°, parlaklık ×0,92. '
          'Yer tutucu bir şey <b style="color:#EFE7D6">yazmaz</b> (üretimde etiket yok); <b style="color:#EFE7D6">debug yapıda</b> köşede 26 px “YER TUTUCU” etiketi görünür. '
          'Başarım ikonu yoksa: <code>stat</code> ailesine göre mevcut ikon (kılavuz DESIGN.md §6.3), plaka çerçevesi aynı.</div>')
    page("07-yer-tutucu-stili","Yer tutucu stili",b,"Yer tutucu stili")

menu(); menu(anat=True, name="01b-ana-menu-anatomi")
menu(sel_name="Gunslinger", ach="0/22", name="01c-ana-menu-ilk-acilis")
chars(); chars(anat=True, name="02a-karakterler-anatomi")
chars(focus="barutcu", selected="barutcu", name="02b-karakterler-secili")
chars(focus="barutcu", selected="gunslinger", locked=True, name="02c-karakterler-kilitli")
chars(focus="gunslinger", selected="gunslinger", single=True, name="02d-karakterler-tek")
ach(); ach(anat=True, name="03a-basarimlar-anatomi"); ach(empty=True, name="03b-basarimlar-bos")
hud_toast(); hud_toast(anat=True, name="04a-hud-bildirim-anatomi"); toast_states()
levelup(); levelup(ad="BARUTÇU", ph=True, name="05b-seviye-atlama-barutcu"); levelup(ad="BARUTÇU", noportrait=True, name="05c-seviye-atlama-portresiz"); levelup(anat=True, name="05a-seviye-atlama-anatomi")
result(); result(anat=True, name="06a-sonuc-anatomi")
tokens_sheet()
print("ok")
