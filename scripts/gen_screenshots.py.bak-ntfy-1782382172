#!/usr/bin/env python3
"""
App Store Screenshot Generator — NickDegs Panel / NickDegs Business / RealVirtuality AI
iOS 26 uyumlu, tüm desteklenen diller, abonelik ekranları dahil.
Kullanım: python3 gen_screenshots.py [--app panel|business|rv] [--out /path]
"""

import os, sys, json, textwrap, argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONT_REG  = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"
FONT_AR   = "/usr/share/fonts/truetype/noto/NotoSansArabic-Bold.ttf"

# Ekran boyutları (genişlik × yükseklik)
SIZES = {
    "6.9": (1320, 2868),   # iPhone 16 Pro Max — APP_IPHONE_69
    "6.7": (1290, 2796),   # iPhone 15/16 Plus — APP_IPHONE_67
    "6.5": (1242, 2688),   # iPhone 11/12/13/14 Pro Max — APP_IPHONE_65
}
PRIMARY_SIZES = ["6.9", "6.5"]   # En az bu ikisi gerekli

# ─── Renk paleti ────────────────────────────────────────────────────────────
PANEL_ACCENT   = (41, 121, 216)     # Mavi
BUSINESS_ACCENT= (255, 149,   0)    # Turuncu
RV_ACCENT      = (139,  92, 246)    # Mor

BG_DARK   = (7,  10, 20)
BG_DARK2  = (13, 21, 39)
BG_CARD   = (20, 30, 48)
BG_CARD2  = (26, 38, 60)
BG_SCREEN = (10, 16, 28)
TEXT_WHITE= (255, 255, 255)
TEXT_GRAY = (136, 153, 187)
TEXT_LIGHT= (180, 196, 224)
BORDER    = (45,  58, 85)

def load_font(size, bold=True, arabic=False):
    path = FONT_AR if arabic else (FONT_BOLD if bold else FONT_REG)
    try:
        return ImageFont.truetype(path, size)
    except:
        return ImageFont.load_default()

def hex2rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def grad_rect(draw, x1, y1, x2, y2, col1, col2, vertical=True):
    """Dikey veya yatay gradient dikdörtgen."""
    steps = (y2 - y1) if vertical else (x2 - x1)
    for i in range(steps):
        t = i / max(steps, 1)
        r = int(col1[0] + (col2[0]-col1[0]) * t)
        g = int(col1[1] + (col2[1]-col1[1]) * t)
        b = int(col1[2] + (col2[2]-col1[2]) * t)
        if vertical:
            draw.line([(x1, y1+i), (x2, y1+i)], fill=(r,g,b))
        else:
            draw.line([(x1+i, y1), (x1+i, y2)], fill=(r,g,b))

def blend(c1, c2, t):
    return tuple(int(c1[i] + (c2[i]-c1[i]) * t) for i in range(3))

def draw_bg(img, w, h, accent):
    draw = ImageDraw.Draw(img)
    # Ana gradient
    grad_rect(draw, 0, 0, w, h//2, BG_DARK, BG_DARK2)
    grad_rect(draw, 0, h//2, w, h, BG_DARK2, BG_DARK)
    # Accent glow (sol üst)
    glow_col = blend(BG_DARK, accent, 0.12)
    for i in range(200):
        t = 1 - i/200
        r = i * 5
        alpha = int(t * 30)
        col = blend(BG_DARK, accent, t * 0.15)
        draw.ellipse([w//4-r, -r, w//4+r, r], fill=col)
    # Sağ alt glow
    for i in range(150):
        t = 1 - i/150
        r = i * 4
        col = blend(BG_DARK2, accent, t * 0.10)
        draw.ellipse([w - r, h - r, w + r, h + r], fill=col)

def draw_phone_frame(img, draw, fw, fh, fx, fy, accent, screen_content_fn=None):
    """iPhone frame çiz + içini doldur."""
    r = fw // 10  # köşe yarıçapı
    # Frame dış gölge
    shadow = Image.new("RGBA", img.size, (0,0,0,0))
    sd = ImageDraw.Draw(shadow)
    for i in range(20, 0, -1):
        alpha = int((20-i)/20 * 40)
        sd.rounded_rectangle([fx-i, fy-i, fx+fw+i, fy+fh+i], radius=r+i, fill=(0,0,0,alpha))
    img.paste(Image.fromarray(shadow.convert("RGB")), mask=shadow.split()[3])

    # Frame gövdesi (koyu)
    frame_col = (28, 36, 54)
    draw.rounded_rectangle([fx, fy, fx+fw, fy+fh], radius=r, fill=frame_col,
                           outline=(50, 65, 90), width=4)

    # İç ekran
    margin = int(fw * 0.05)
    sx, sy = fx + margin, fy + margin
    sw, sh = fw - margin*2, fh - margin*2
    sr = r - margin//2
    draw.rounded_rectangle([sx, sy, sx+sw, sy+sh], radius=sr, fill=BG_SCREEN)

    # Notch / Dynamic Island
    ni_w = int(sw * 0.28)
    ni_h = 28
    ni_x = sx + (sw - ni_w) // 2
    ni_y = sy + 18
    draw.rounded_rectangle([ni_x, ni_y, ni_x+ni_w, ni_y+ni_h], radius=14, fill=(10, 14, 24))

    # Accent çerçeve glow
    glow_col = tuple(int(c * 0.7) for c in accent) + (40,)

    # Durum çubuğu (saat + sinyal)
    sf_s = load_font(22)
    status_y = sy + ni_y + ni_h + 8
    draw.text((sx + 24, status_y), "9:41", font=sf_s, fill=TEXT_LIGHT)
    draw.text((sx + sw - 90, status_y), "●●●", font=sf_s, fill=TEXT_LIGHT)

    return (sx, sy, sw, sh, sr)  # ekran koordinatları

def text_center(draw, text, x, y, w, font, fill, arabic=False):
    """Metni yatayda ortala."""
    bbox = font.getbbox(text)
    tw = bbox[2] - bbox[0]
    draw.text((x + (w - tw) // 2, y), text, font=font, fill=fill)
    return bbox[3] - bbox[1]

def wrap_text(draw, text, x, y, max_w, font, fill, line_gap=8, arabic=False):
    """Metni satırlara böl ve çiz."""
    words = text.split()
    lines, line = [], []
    for w in words:
        test = ' '.join(line + [w])
        bbox = font.getbbox(test)
        if bbox[2] - bbox[0] > max_w and line:
            lines.append(' '.join(line)); line = [w]
        else:
            line.append(w)
    if line: lines.append(' '.join(line))
    total_h = 0
    for ln in lines:
        draw.text((x, y + total_h), ln, font=font, fill=fill)
        bbox = font.getbbox(ln)
        total_h += (bbox[3] - bbox[1]) + line_gap
    return total_h

def draw_card(draw, x, y, w, h, fill=BG_CARD, border=BORDER, radius=20):
    draw.rounded_rectangle([x, y, x+w, y+h], radius=radius, fill=fill, outline=border, width=1)

def draw_pill(draw, x, y, text, font, bg_col, text_col=TEXT_WHITE, pad_x=20, pad_h=10):
    bbox = font.getbbox(text)
    tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]
    pw = tw + pad_x*2; ph = th + pad_h*2
    draw.rounded_rectangle([x, y, x+pw, y+ph], radius=ph//2, fill=bg_col)
    draw.text((x+pad_x, y+pad_h), text, font=font, fill=text_col)
    return pw, ph

def draw_icon_circle(draw, cx, cy, r, icon_char, font, bg, fg=TEXT_WHITE):
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=bg)
    bbox = font.getbbox(icon_char)
    iw = bbox[2] - bbox[0]; ih = bbox[3] - bbox[1]
    draw.text((cx - iw//2, cy - ih//2), icon_char, font=font, fill=fg)

# ─────────────────────────────────────────────────────────────────────────────
#  NickDegs Panel Ekranları
# ─────────────────────────────────────────────────────────────────────────────

PANEL_SCREENS = [
    # (dosya_adi, başlık_tr, başlık_en, alt_tr, alt_en)
    ("01_dashboard", "Sunucunuzun\nTam Kontrolü", "Full Control\nOf Your Server",
     "Anlık sistem izleme, servis durumları\nve alarm bildirimleri bir arada.",
     "Real-time system monitoring, service\nhealth and alerts in one place."),
    ("02_isletmeler", "Tüm Müşterileriniz\nBir Ekranda", "All Your Customers\nIn One View",
     "Sektöre göre gruplandırılmış işletmeler,\nanında erişim ve kontrol.",
     "Businesses grouped by sector,\ninstant access and full control."),
    ("03_sistem", "Anlık\nSistem İzleme", "Real-time\nSystem Monitoring",
     "CPU, bellek, disk ve ağ kullanımını\ncanlı takip edin.",
     "Monitor CPU, memory, disk and\nnetwork usage live."),
    ("04_guvenlik", "Banka Seviyesi\nGüvenlik", "Bank-Level\nSecurity",
     "2FA ve passkey korumalı giriş,\nher işlem kayıt altında.",
     "2FA and passkey protected login,\nevery action fully audited."),
    ("05_bildirim", "Hiçbir Uyarıyı\nKaçırmayın", "Never Miss\nAn Alert",
     "Kritik olaylar anında Telegram\nve ntfy bildirimiyle size ulaşır.",
     "Critical events reach you instantly\nvia Telegram and push notifications."),
]

BUSINESS_SCREENS = {
    "tr": [
        ("01_hero", "İşletmenizi\nHer Yerden\nYönetin", "Restoran, kafe, market, kuaför ve daha fazlası.\nTek uygulama, tam kontrol."),
        ("02_katalog", "Sektörünüze\nÖzel Panel", "İşletme türünüze göre özelleştirilmiş\npanel ve araçlar."),
        ("03_abonelik", "Planınızı Seçin\nHemen Başlayın", "Yıllık planlarda %40'a kadar tasarruf edin.\nOtomatik kurulum, anında kullanım."),
        ("04_siparis", "Siparişleri\nAnında Görün", "Masa ve paket siparişleri gerçek zamanlı,\nbildirimle haber verin."),
        ("05_ekip", "Ekibinizi\nKolayca Yönetin", "Personel yetkilendirme, vardiya takibi\nve performans özeti."),
        ("06_analitik", "Büyüme\nAnalitikleri", "Günlük, haftalık ve aylık gelir raporları.\nKararlarınızı veriye dayandırın."),
    ],
    "en": [
        ("01_hero", "Manage Your\nBusiness\nFrom Anywhere", "Restaurant, cafe, store, salon and more.\nOne app, full control."),
        ("02_katalog", "Panel Built\nFor Your Sector", "Tools and panels customized\nfor your business type."),
        ("03_abonelik", "Choose Your Plan\nStart Instantly", "Save up to 40% with annual plans.\nAuto-setup, instant access."),
        ("04_siparis", "See Orders\nInstantly", "Table and delivery orders in real time,\nnotified the moment they arrive."),
        ("05_ekip", "Manage Your\nTeam Easily", "Staff permissions, shift tracking\nand performance summary."),
        ("06_analitik", "Growth\nAnalytics", "Daily, weekly and monthly revenue reports.\nBase your decisions on data."),
    ],
    "de": [
        ("01_hero", "Verwalten Sie\nIhr Unternehmen\nVon Überall", "Restaurant, Café, Markt, Salon und mehr.\nEine App, volle Kontrolle."),
        ("02_katalog", "Panel Für\nIhre Branche", "Angepasste Tools und Panels\nfür Ihren Unternehmenstyp."),
        ("03_abonelik", "Plan Wählen\nSofort Starten", "Bis zu 40% Ersparnis mit Jahresplan.\nAutomatische Einrichtung."),
        ("04_siparis", "Bestellungen\nSofort Sehen", "Tisch- und Lieferbestellungen in Echtzeit,\nsofort benachrichtigt."),
        ("05_ekip", "Team Einfach\nVerwalten", "Personalberechtigungen, Schichtplanung\nund Leistungsübersicht."),
        ("06_analitik", "Wachstums-\nAnalysen", "Tägliche, wöchentliche Umsatzberichte.\nEntscheidungen auf Datenbasis."),
    ],
    "fr": [
        ("01_hero", "Gérez Votre\nEntreprise\nPartout", "Restaurant, café, magasin, salon et plus.\nUne app, contrôle total."),
        ("02_katalog", "Panneau Pour\nVotre Secteur", "Outils et panneaux personnalisés\npour votre type d'entreprise."),
        ("03_abonelik", "Choisissez\nVotre Plan", "Économisez jusqu'à 40% avec le plan annuel.\nConfiguration automatique."),
        ("04_siparis", "Commandes\nEn Temps Réel", "Commandes sur table et livraison en direct,\nnotifié instantanément."),
        ("05_ekip", "Gérez Votre\nÉquipe", "Permissions du personnel, suivi des équipes\net résumé des performances."),
        ("06_analitik", "Analyses\nde Croissance", "Rapports de revenus quotidiens, hebdomadaires.\nDécisions basées sur les données."),
    ],
    "es": [
        ("01_hero", "Gestiona Tu\nNegocio\nDesde Cualquier Lugar", "Restaurante, café, tienda, salón y más.\nUna app, control total."),
        ("02_katalog", "Panel Para\nTu Sector", "Herramientas y paneles personalizados\npara tu tipo de negocio."),
        ("03_abonelik", "Elige Tu Plan\nEmpieza Ya", "Ahorra hasta 40% con plan anual.\nConfiguración automática."),
        ("04_siparis", "Ve Pedidos\nAl Instante", "Pedidos de mesa y entrega en tiempo real,\nnotificado al instante."),
        ("05_ekip", "Gestiona\nTu Equipo", "Permisos de personal, seguimiento de turnos\ny resumen de rendimiento."),
        ("06_analitik", "Análisis\nde Crecimiento", "Informes de ingresos diarios y semanales.\nDecisiones basadas en datos."),
    ],
}

RV_SCREENS = {
    "tr": [
        ("01_hero", "Yapay Zeka ile\nYaratın", "Görsel üretimi, yüz değiştirme, ses transkripti\nve daha fazlası tek uygulamada."),
        ("02_gorsel", "Çarpıcı Görseller\nSaniyeler İçinde", "Metin yazın, AI sizi şaşırtsın.\nFLUX modeli ile fotorealistik sonuçlar."),
        ("03_yuz", "Yüzünüzü\nDeğiştirin", "Herhangi bir görsele yüzünüzü ekleyin.\nHiper gerçekçi, anında sonuç."),
        ("04_transkript", "Sesi Metne\nÇevirin", "Konuşmaları otomatik transkript edin.\n17 dilde çeviri desteği."),
        ("05_kredi", "Kredi Al\nDaha Fazla Yarat", "Kullandıkça öde sistemi.\nHer araç için uygun kredi paketleri."),
        ("06_tema", "Kişisel\nDeneyim", "Koyu/açık mod, 7 dil seçeneği\nve özelleştirilmiş arayüz."),
    ],
    "en": [
        ("01_hero", "Create With\nArtificial Intelligence", "Image generation, face swap, speech transcription\nand more in one app."),
        ("02_gorsel", "Stunning Images\nIn Seconds", "Type a prompt, let AI surprise you.\nPhotorealistic results with FLUX model."),
        ("03_yuz", "Swap Your\nFace", "Add your face to any image.\nHyper-realistic, instant result."),
        ("04_transkript", "Convert Speech\nTo Text", "Automatically transcribe conversations.\nTranslation support in 17 languages."),
        ("05_kredi", "Get Credits\nCreate More", "Pay only for what you use.\nAffordable credit packs for every tool."),
        ("06_tema", "Personal\nExperience", "Dark/light mode, 7 language options\nand customized interface."),
    ],
    "de": [
        ("01_hero", "Erschaffen Sie\nMit KI", "Bildgenerierung, Gesichtstausch, Sprachtranskription\nund mehr in einer App."),
        ("02_gorsel", "Beeindruckende\nBilder In Sekunden", "Prompt eingeben, KI überrascht Sie.\nFotorealistische Ergebnisse mit FLUX."),
        ("03_yuz", "Gesicht\nTauschen", "Fügen Sie Ihr Gesicht in jedes Bild ein.\nHyperrealistisch, sofortiges Ergebnis."),
        ("04_transkript", "Sprache Zu\nText Konvertieren", "Gespräche automatisch transkribieren.\nÜbersetzung in 17 Sprachen."),
        ("05_kredi", "Credits Kaufen\nMehr Erstellen", "Zahlen Sie nur für das, was Sie nutzen.\nGünstige Pakete für jedes Tool."),
        ("06_tema", "Persönliches\nErlebnis", "Dunkel/Hell-Modus, 7 Sprachen\nund individuelles Interface."),
    ],
    "fr": [
        ("01_hero", "Créez Avec\nL'Intelligence Artificielle", "Génération d'images, échange de visage, transcription\net plus dans une seule app."),
        ("02_gorsel", "Images\nÉpoustouflantes", "Tapez un prompt, laissez l'IA vous surprendre.\nRésultats photoréalistes avec FLUX."),
        ("03_yuz", "Échangez\nVotre Visage", "Ajoutez votre visage à n'importe quelle image.\nHyperréaliste, résultat instantané."),
        ("04_transkript", "Convertir La\nParole En Texte", "Transcription automatique des conversations.\nTraduction en 17 langues."),
        ("05_kredi", "Acheter Des\nCrédits", "Payez uniquement ce que vous utilisez.\nPacks abordables pour chaque outil."),
        ("06_tema", "Expérience\nPersonnalisée", "Mode sombre/clair, 7 langues\net interface personnalisée."),
    ],
    "es": [
        ("01_hero", "Crea Con\nInteligencia Artificial", "Generación de imágenes, intercambio de cara, transcripción\ny más en una sola app."),
        ("02_gorsel", "Imágenes\nImpresionantes", "Escribe un prompt, deja que la IA te sorprenda.\nResultados fotorrealistas con FLUX."),
        ("03_yuz", "Cambia\nTu Cara", "Añade tu cara a cualquier imagen.\nHiper-realista, resultado instantáneo."),
        ("04_transkript", "Convertir Voz\nA Texto", "Transcripción automática de conversaciones.\nTraducción en 17 idiomas."),
        ("05_kredi", "Obtén Créditos\nCrea Más", "Paga solo por lo que usas.\nPaquetes asequibles para cada herramienta."),
        ("06_tema", "Experiencia\nPersonal", "Modo oscuro/claro, 7 idiomas\ne interfaz personalizado."),
    ],
    "ar": [
        ("01_hero", "أنشئ مع\nالذكاء الاصطناعي", "توليد الصور، تبديل الوجوه، نسخ الصوت\nوالمزيد في تطبيق واحد."),
        ("02_gorsel", "صور مذهلة\nفي ثوانٍ", "اكتب وصفاً، دع الذكاء الاصطناعي يفاجئك.\nنتائج واقعية مع نموذج FLUX."),
        ("03_yuz", "غيّر\nوجهك", "أضف وجهك إلى أي صورة.\nواقعية فائقة، نتيجة فورية."),
        ("04_transkript", "تحويل الكلام\nإلى نص", "نسخ المحادثات تلقائياً.\nدعم الترجمة بـ17 لغة."),
        ("05_kredi", "احصل على\nرصيد وأنشئ أكثر", "ادفع فقط لما تستخدمه.\nحزم رصيد مناسبة لكل أداة."),
        ("06_tema", "تجربة\nشخصية", "وضع مظلم/فاتح، 7 لغات\nوواجهة مخصصة."),
    ],
    "ru": [
        ("01_hero", "Создавайте\nС ИИ", "Генерация изображений, замена лиц, транскрипция\nи многое другое в одном приложении."),
        ("02_gorsel", "Потрясающие\nИзображения", "Введите промпт, пусть ИИ вас удивит.\nФотореалистичные результаты с FLUX."),
        ("03_yuz", "Замените\nЛицо", "Добавьте своё лицо на любое изображение.\nГиперреалистично, мгновенный результат."),
        ("04_transkript", "Преобразование\nРечи В Текст", "Автоматическая транскрипция разговоров.\nПеревод на 17 языков."),
        ("05_kredi", "Купите Кредиты\nСоздавайте Больше", "Платите только за то, что используете.\nДоступные пакеты для каждого инструмента."),
        ("06_tema", "Личный\nОпыт", "Тёмный/светлый режим, 7 языков\nи настроенный интерфейс."),
    ],
}

# ─── Ekran içerik çizicileri ─────────────────────────────────────────────────

def draw_panel_screen(draw, sx, sy, sw, sh, screen_idx, accent, scale=1.0):
    """Panel app içerikleri."""
    s = scale
    font_m = load_font(int(28*s)); font_s = load_font(int(22*s)); font_xs = load_font(int(18*s))
    font_mb = load_font(int(30*s)); font_sm = load_font(int(24*s), bold=False)

    y = sy + int(60*s)
    cx = sx + sw//2

    if screen_idx == 0:  # Dashboard
        # App başlığı
        t = load_font(int(36*s))
        text_center(draw, "⚡ NickDegs Panel", sx, y, sw, t, PANEL_ACCENT); y += int(55*s)
        # Metrik kartlar (3 col)
        metrics = [("CPU", "23%", PANEL_ACCENT), ("RAM", "8.2G", (100,180,100)), ("Disk", "64%", (255,160,50))]
        card_w = int((sw - int(50*s)) // 3)
        for i, (lbl, val, col) in enumerate(metrics):
            cx2 = sx + int(16*s) + i * (card_w + int(8*s))
            draw_card(draw, cx2, y, card_w, int(90*s), fill=BG_CARD)
            draw.text((cx2+int(12*s), y+int(10*s)), lbl, font=font_xs, fill=TEXT_GRAY)
            draw.text((cx2+int(12*s), y+int(32*s)), val, font=font_mb, fill=col)
        y += int(105*s)
        # Servis listesi
        services = [("nginx",True),("payment-service",True),("panel-auth",True),("n8n",True),("nickdegs-e2e",False)]
        for svc, up in services:
            col = (80,200,120) if up else (220,80,80)
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(54*s))
            draw.ellipse([sx+int(24*s), y+int(18*s), sx+int(38*s), y+int(36*s)], fill=col)
            draw.text((sx+int(50*s), y+int(15*s)), svc, font=font_s, fill=TEXT_WHITE)
            status = "Çalışıyor" if up else "Durduruldu"
            draw.text((sx+sw-int(120*s), y+int(15*s)), status, font=font_xs, fill=TEXT_GRAY)
            y += int(62*s)
        # Grafik placeholder
        draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(130*s)); y += int(145*s)
        draw.text((sx+int(20*s), y-int(110*s)), "Son 24 Saat — Sistem Yükü", font=font_xs, fill=TEXT_GRAY)

    elif screen_idx == 1:  # İşletmeler
        t = load_font(int(32*s))
        text_center(draw, "👥 Müşteriler", sx, y, sw, t, TEXT_WHITE); y += int(55*s)
        sectors = [("🍽 Restoran", 3),("☕ Kafe", 2),("✂ Kuaför", 4),("⚖ Hukuk", 1),("🏥 Klinik", 2)]
        for sector, count in sectors:
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(72*s))
            draw.text((sx+int(24*s), y+int(18*s)), sector, font=font_mb, fill=TEXT_WHITE)
            draw.text((sx+sw-int(90*s), y+int(22*s)), f"{count} işletme", font=font_xs, fill=TEXT_GRAY)
            y += int(80*s)
        # Toplam
        draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(60*s), fill=(20,40,70))
        draw.text((sx+int(24*s), y+int(15*s)), "Toplam: 12 aktif işletme", font=font_s, fill=PANEL_ACCENT)

    elif screen_idx == 2:  # Sistem
        t = load_font(int(30*s))
        text_center(draw, "📊 Sistem İzleme", sx, y, sw, t, TEXT_WHITE); y += int(55*s)
        # Büyük daire gösterge (CPU)
        r = int(80*s); cc = (cx, y+r+int(10*s))
        draw.ellipse([cc[0]-r, cc[1]-r, cc[0]+r, cc[1]+r], fill=BG_CARD, outline=BORDER, width=3)
        draw.arc([cc[0]-r, cc[1]-r, cc[0]+r, cc[1]+r], start=135, end=135+int(0.23*270), fill=PANEL_ACCENT, width=8)
        draw.text((cc[0]-int(25*s), cc[1]-int(20*s)), "23%", font=load_font(int(40*s)), fill=TEXT_WHITE)
        draw.text((cc[0]-int(15*s), cc[1]+int(18*s)), "CPU", font=font_xs, fill=TEXT_GRAY)
        y += int(200*s)
        # İstatistik satırları
        stats = [("Uptime","99.8%","15 gün 4 saat"),("RAM","8.2/14GB","59%"),("Ağ","↑234 MB/s","↓89 MB/s")]
        for lbl,val,sub in stats:
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(64*s))
            draw.text((sx+int(20*s), y+int(10*s)), lbl, font=font_xs, fill=TEXT_GRAY)
            draw.text((sx+int(20*s), y+int(30*s)), val, font=font_m, fill=TEXT_WHITE)
            draw.text((sx+sw-int(140*s), y+int(26*s)), sub, font=font_xs, fill=TEXT_GRAY)
            y += int(72*s)

    elif screen_idx == 3:  # Güvenlik
        t = load_font(int(30*s))
        text_center(draw, "🔒 Güvenlik", sx, y, sw, t, TEXT_WHITE); y += int(55*s)
        items = [
            ("🛡 CrowdSec", "1.2K+ ban", (80,200,120)),
            ("🔑 2FA Aktif", "Tüm girişler", (80,200,120)),
            ("🌐 CF WAF", "87 engelleme/gün", (80,200,120)),
            ("📋 Audit Log", "Her işlem kayıtlı", PANEL_ACCENT),
            ("🚨 Son Olay", "3 saat önce", (255,200,50)),
        ]
        for icon_lbl, val, col in items:
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(64*s))
            draw.text((sx+int(20*s), y+int(18*s)), icon_lbl, font=font_s, fill=TEXT_WHITE)
            draw.text((sx+sw-int(200*s), y+int(20*s)), val, font=font_xs, fill=col)
            y += int(72*s)

    elif screen_idx == 4:  # Bildirim
        t = load_font(int(30*s))
        text_center(draw, "🔔 Bildirimler", sx, y, sw, t, TEXT_WHITE); y += int(55*s)
        notifs = [
            ("✅","payment-service yeniden başlatıldı","12:03","INFO"),
            ("⚠️","Disk kullanımı %78","11:45","UYARI"),
            ("🚨","3 başarısız giriş denemesi","09:22","ALERT"),
            ("✅","SSL sertifikası yenilendi","08:00","INFO"),
            ("💰","Yeni abonelik: Pro Plan","07:55","SATIŞ"),
        ]
        for ico, msg, time_s, tag in notifs:
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(74*s))
            draw.text((sx+int(16*s), y+int(14*s)), ico + " " + msg[:35], font=font_xs, fill=TEXT_WHITE)
            col = (80,200,120) if tag=="INFO" else (255,200,50) if tag=="UYARI" else (220,80,80) if tag=="ALERT" else PANEL_ACCENT
            _, ph = draw_pill(draw, sx+int(16*s), y+int(42*s), tag, font_xs, col, pad_x=8, pad_h=4)
            draw.text((sx+sw-int(90*s), y+int(20*s)), time_s, font=font_xs, fill=TEXT_GRAY)
            y += int(82*s)


def draw_business_screen(draw, sx, sy, sw, sh, screen_idx, title, subtitle, accent, scale=1.0):
    s = scale
    font_l = load_font(int(36*s)); font_m = load_font(int(28*s)); font_s = load_font(int(22*s))
    font_xs = load_font(int(18*s)); font_mb = load_font(int(30*s)); font_sm = load_font(int(24*s), bold=False)
    y = sy + int(55*s); cx = sx + sw//2

    if screen_idx == 0:  # Hero - sektör listesi
        text_center(draw, "NickDegs Business", sx, y, sw, font_m, accent); y += int(48*s)
        sectors = [
            ("🍽","Restoran / Lokanta"),("☕","Kafe"),("🛒","Market / Mağaza"),
            ("🏨","Otel / Pansiyon"),("✂","Kuaför / Güzellik"),("⚕","Klinik / Hastane"),
            ("🐾","Veteriner"),("💪","Spor Salonu"),
        ]
        col_w = (sw - int(32*s)) // 2
        for i, (ico, name) in enumerate(sectors):
            row, col = i // 2, i % 2
            px = sx + int(8*s) + col * (col_w + int(8*s))
            py = y + row * int(82*s)
            draw_card(draw, px, py, col_w, int(74*s))
            draw.text((px+int(16*s), py+int(14*s)), ico, font=font_m, fill=accent)
            draw.text((px+int(48*s), py+int(20*s)), name[:18], font=font_xs, fill=TEXT_WHITE)

    elif screen_idx == 1:  # Katalog
        text_center(draw, "💼 İşletme Araçları", sx, y, sw, font_m, accent); y += int(50*s)
        tools = [
            ("📊","Sipariş & Satış","Gerçek zamanlı takip",PANEL_ACCENT),
            ("👥","Personel Yönetimi","Vardiya & yetki",RV_ACCENT),
            ("📋","Stok Takibi","Otomatik uyarılar",(100,200,100)),
            ("💬","Müşteri Mesajları","Hızlı yanıt",(255,200,50)),
            ("📈","Raporlar","Haftalık & aylık",PANEL_ACCENT),
        ]
        for ico, lbl, sub, col in tools:
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(70*s))
            draw.text((sx+int(20*s), y+int(14*s)), ico+" "+lbl, font=font_s, fill=TEXT_WHITE)
            draw.text((sx+int(20*s), y+int(42*s)), sub, font=font_xs, fill=TEXT_GRAY)
            y += int(78*s)

    elif screen_idx == 2:  # Abonelik — ZORUNLU ekran
        text_center(draw, "📦 Planlar", sx, y, sw, font_m, TEXT_WHITE); y += int(40*s)
        text_center(draw, "Yıllık planla %40 tasarruf", sx, y, sw, font_xs, TEXT_GRAY); y += int(40*s)
        plans = [
            ("Başlangıç","₺1.490/yıl","1 lokasyon · Sipariş · QR menü",PANEL_ACCENT, False),
            ("Pro","₺2.490/yıl","3 lokasyon · Personel · Analitik",RV_ACCENT, True),
            ("Kurumsal","₺4.490/yıl","Sınırsız · Özel domain · Öncelikli",(255,149,0), False),
        ]
        for name, price, features, col, popular in plans:
            h_c = int(130*s) if popular else int(114*s)
            bg = blend(BG_CARD, col, 0.08) if popular else BG_CARD
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), h_c, fill=bg, border=col if popular else BORDER)
            if popular:
                pw, _ = draw_pill(draw, sx+sw-int(140*s), y+int(8*s), "⭐ Popüler", font_xs, col, pad_x=8, pad_h=4)
            draw.text((sx+int(20*s), y+int(12*s)), name, font=font_mb, fill=TEXT_WHITE)
            draw.text((sx+int(20*s), y+int(46*s)), price, font=font_m, fill=col)
            draw.text((sx+int(20*s), y+int(78*s)), features, font=font_xs, fill=TEXT_GRAY)
            if popular: draw.text((sx+int(20*s), y+int(98*s)), "▼ Hemen Başla", font=font_xs, fill=col)
            y += h_c + int(12*s)
        # Güven rozetleri
        y += int(8*s)
        draw.text((sx+int(20*s), y), "🔒 App Store aracılığıyla güvenli ödeme", font=font_xs, fill=TEXT_GRAY)
        y += int(28*s)
        draw.text((sx+int(20*s), y), "📱 İlk 7 gün ücretsiz · İstediğin zaman iptal", font=font_xs, fill=TEXT_GRAY)

    elif screen_idx == 3:  # Sipariş
        text_center(draw, "📋 Siparişler", sx, y, sw, font_m, TEXT_WHITE); y += int(50*s)
        # Özet
        draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(90*s), fill=(20,40,70))
        draw.text((sx+int(20*s), y+int(12*s)), "Bugün", font=font_xs, fill=TEXT_GRAY)
        draw.text((sx+int(20*s), y+int(36*s)), "₺4.280", font=load_font(int(44*s)), fill=(80,200,120))
        draw.text((sx+sw//2, y+int(36*s)), "23 sipariş", font=font_m, fill=TEXT_WHITE)
        y += int(105*s)
        orders = [("Masa 4","3 kişilik","₺320","Hazırlanıyor"),
                  ("Paket #44","Teslimat","₺185","Yolda"),
                  ("Masa 7","2 kişilik","₺410","Teslim"),
                  ("Paket #45","Teslimat","₺95","Bekliyor")]
        for tbl, det, amt, st in orders:
            col = (255,200,50) if st=="Hazırlanıyor" else (80,180,255) if st=="Yolda" else (80,200,120) if st=="Teslim" else TEXT_GRAY
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(68*s))
            draw.text((sx+int(20*s), y+int(10*s)), tbl, font=font_s, fill=TEXT_WHITE)
            draw.text((sx+int(20*s), y+int(38*s)), det, font=font_xs, fill=TEXT_GRAY)
            draw.text((sx+sw//2, y+int(10*s)), amt, font=font_m, fill=accent)
            draw_pill(draw, sx+sw-int(160*s), y+int(22*s), st, font_xs, col+(50,) if len(col)==3 else col, col, pad_x=8, pad_h=5)
            y += int(76*s)

    elif screen_idx == 4:  # Ekip
        text_center(draw, "👥 Ekip", sx, y, sw, font_m, TEXT_WHITE); y += int(50*s)
        staff = [("Ahmet K.","Şef","🟢 Çalışıyor"),("Fatma Y.","Kasiyer","🟢 Çalışıyor"),
                 ("Mehmet B.","Garson","🟡 Mola"),("Ayşe T.","Mutfak","🔴 İzinli")]
        for name, role, status in staff:
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(74*s))
            r = int(24*s)
            draw.ellipse([sx+int(16*s), y+int(14*s), sx+int(16*s)+r*2, y+int(14*s)+r*2], fill=accent)
            draw.text((sx+int(18*s)+int(5*s), y+int(20*s)), name[0], font=font_s, fill=TEXT_WHITE)
            draw.text((sx+int(68*s), y+int(12*s)), name, font=font_s, fill=TEXT_WHITE)
            draw.text((sx+int(68*s), y+int(38*s)), role, font=font_xs, fill=TEXT_GRAY)
            draw.text((sx+sw-int(150*s), y+int(26*s)), status, font=font_xs, fill=TEXT_GRAY)
            y += int(82*s)

    elif screen_idx == 5:  # Analitik
        text_center(draw, "📈 Analitikler", sx, y, sw, font_m, TEXT_WHITE); y += int(50*s)
        periods = [("Bu Hafta","₺18.420","+12%",(80,200,120)),
                   ("Bu Ay","₺74.850","+8%",(80,200,120)),
                   ("Yıllık","₺890.000","+24%",accent)]
        for period, val, pct, col in periods:
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(80*s))
            draw.text((sx+int(20*s), y+int(12*s)), period, font=font_xs, fill=TEXT_GRAY)
            draw.text((sx+int(20*s), y+int(34*s)), val, font=font_mb, fill=TEXT_WHITE)
            draw_pill(draw, sx+sw-int(120*s), y+int(28*s), pct, font_xs, col, pad_x=10, pad_h=5)
            y += int(90*s)
        draw.text((sx+int(8*s), y+int(10*s)), "En Çok Satan", font=font_s, fill=TEXT_GRAY); y += int(45*s)
        tops = [("1.","Burger Menü","234 adet"),("2.","Çay","412 bardak"),("3.","Tatlı Tabağı","98 adet")]
        for rank, item, cnt in tops:
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(54*s))
            draw.text((sx+int(20*s), y+int(14*s)), rank+" "+item, font=font_s, fill=TEXT_WHITE)
            draw.text((sx+sw-int(130*s), y+int(16*s)), cnt, font=font_xs, fill=TEXT_GRAY)
            y += int(62*s)


def draw_rv_screen(draw, sx, sy, sw, sh, screen_idx, accent, scale=1.0, arabic=False):
    s = scale
    font_m = load_font(int(28*s), arabic=arabic)
    font_s = load_font(int(22*s), arabic=arabic)
    font_xs = load_font(int(18*s), arabic=arabic)
    font_l = load_font(int(36*s), arabic=arabic)
    font_mb = load_font(int(30*s), arabic=arabic)
    y = sy + int(55*s); cx = sx + sw//2

    if screen_idx == 0:  # Hero — araç gridi
        text_center(draw, "RealVirtuality AI", sx, y, sw, load_font(int(34*s)), accent); y += int(50*s)
        tools_grid = [
            ("🖼","Görsel Üretim",PANEL_ACCENT), ("🤳","Yüz Değiştirme",RV_ACCENT),
            ("🎤","Transkript",accent),           ("📈","Upscale",PANEL_ACCENT),
            ("💬","AI Sohbet",RV_ACCENT),         ("🎨","Stil Aktarma",accent),
        ]
        cell_w = (sw - int(32*s)) // 2
        for i, (ico, name, col) in enumerate(tools_grid):
            row, col2 = i // 2, i % 2
            px = sx + int(8*s) + col2 * (cell_w + int(16*s))
            py = y + row * int(110*s)
            draw_card(draw, px, py, cell_w, int(100*s), fill=blend(BG_CARD, col, 0.08), border=col)
            t_ico = load_font(int(38*s))
            draw.text((px+int(16*s), py+int(10*s)), ico, font=t_ico, fill=col)
            draw.text((px+int(16*s), py+int(60*s)), name, font=font_s, fill=TEXT_WHITE)
        y += int(340*s)
        # Kredi göstergesi
        draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(52*s), fill=(20,40,70))
        draw.text((sx+int(20*s), y+int(14*s)), "⚡ 320 kredi", font=font_m, fill=(255,220,50))
        draw.text((sx+sw-int(140*s), y+int(16*s)), "Kredi Al →", font=font_s, fill=accent)

    elif screen_idx == 1:  # Görsel üretim
        text_center(draw, "🖼 Görsel Üretim", sx, y, sw, font_m, TEXT_WHITE); y += int(50*s)
        # Prompt kutusu
        draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(100*s), fill=(18,28,46))
        draw.text((sx+int(20*s), y+int(12*s)), "Prompt", font=font_xs, fill=TEXT_GRAY)
        prompt_text = "A serene Japanese garden at dawn"
        draw.text((sx+int(20*s), y+int(36*s)), prompt_text[:30], font=font_s, fill=TEXT_WHITE)
        y += int(116*s)
        # Sonuç görseli (placeholder)
        draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(380*s), fill=(12,20,38), border=accent)
        # Gradient placeholder
        for gi in range(30):
            t = gi/30
            gc = blend((12,20,38), blend(accent, (80,40,120), 0.5), t*0.3)
            draw.rectangle([sx+int(8*s), y+int(gi*12*s), sx+sw-int(16*s), y+int((gi+1)*12*s)], fill=gc)
        draw.text((sx+sw//2-int(80*s), y+int(170*s)), "FLUX Model", font=font_m, fill=TEXT_GRAY)
        y += int(396*s)
        # Model seçenekleri
        models = [("FLUX Pro","HD",True),("FLUX Dev","Hızlı",False),("SDXL","Sanat",False)]
        for mname, tag, sel in models:
            col = accent if sel else BORDER
            px = sx + int(8*s) + models.index((mname, tag, sel)) * int((sw-int(32*s))//3 + int(8*s))
            draw_card(draw, px, y, int((sw-int(32*s))//3), int(56*s), fill=blend(BG_CARD, accent, 0.1) if sel else BG_CARD, border=col)
            draw.text((px+int(10*s), y+int(8*s)), mname, font=font_xs, fill=TEXT_WHITE if sel else TEXT_GRAY)
            draw.text((px+int(10*s), y+int(30*s)), tag, font=font_xs, fill=col)

    elif screen_idx == 2:  # Yüz değiştirme
        text_center(draw, "🤳 Yüz Değiştirme", sx, y, sw, font_m, TEXT_WHITE); y += int(50*s)
        draw_card(draw, sx+int(8*s), y, int((sw-int(32*s))//2), int(300*s), fill=(12,20,38))
        draw.text((sx+int(20*s), y+int(130*s)), "Kaynak", font=font_s, fill=TEXT_GRAY)
        draw_card(draw, sx+int(16*s)+int((sw-int(32*s))//2), y, int((sw-int(32*s))//2), int(300*s), fill=(12,20,38), border=accent)
        draw.text((sx+int(24*s)+int((sw-int(32*s))//2), y+int(130*s)), "Hedef", font=font_s, fill=TEXT_GRAY)
        y += int(316*s)
        draw.text((cx-int(20*s), y), "↕", font=load_font(int(40*s)), fill=accent); y += int(60*s)
        draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(200*s), fill=blend(BG_CARD, accent, 0.05), border=accent)
        draw.text((cx-int(40*s), y+int(90*s)), "Sonuç ✨", font=font_m, fill=accent)
        y += int(216*s)
        # Buton
        draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(60*s), fill=accent)
        text_center(draw, "Yüz Değiştir", sx+int(8*s), y+int(15*s), sw-int(16*s), font_m, TEXT_WHITE)

    elif screen_idx == 3:  # Transkript
        text_center(draw, "🎤 Transkript", sx, y, sw, font_m, TEXT_WHITE); y += int(50*s)
        draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(120*s), fill=(18,28,46))
        draw.text((sx+int(20*s), y+int(20*s)), "🔴 Kayıt Başlatmak İçin Dokun", font=font_s, fill=TEXT_WHITE)
        # ses dalgası
        for xi in range(20):
            bh = int((20 + (xi % 5) * 15)*s)
            bx = sx + int(40*s) + xi * int(22*s)
            draw.rectangle([bx, y+int(70*s)-bh//2, bx+int(8*s), y+int(70*s)+bh//2], fill=accent)
        y += int(136*s)
        draw_card(draw, sx+int(8*s), y, sw-int(16*s), int(200*s))
        draw.text((sx+int(20*s), y+int(12*s)), "Transkript", font=font_xs, fill=TEXT_GRAY)
        sample = "Bu sabah toplantıda konuşulan konuları not aldım. Proje takvimi Temmuz sonuna ertelendi..."
        wrap_text(draw, sample, sx+int(20*s), y+int(40*s), sw-int(50*s), load_font(int(22*s), bold=False), TEXT_LIGHT)
        y += int(216*s)
        langs = [("🇹🇷","TR"), ("🇺🇸","EN"), ("🇩🇪","DE"), ("🇫🇷","FR"), ("🇸🇦","AR")]
        for i, (flag, code) in enumerate(langs):
            px = sx + int(8*s) + i * int(54*s)
            col = accent if i == 0 else BORDER
            draw_card(draw, px, y, int(46*s), int(46*s), fill=blend(BG_CARD, accent, 0.1) if i==0 else BG_CARD, border=col)
            draw.text((px+int(8*s), y+int(6*s)), flag, font=load_font(int(22*s)), fill=TEXT_WHITE)

    elif screen_idx == 4:  # Kredi / IAP — ZORUNLU
        text_center(draw, "⚡ Kredi Paketleri", sx, y, sw, font_m, TEXT_WHITE); y += int(40*s)
        text_center(draw, "Kullandıkça öde — taahhüt yok", sx, y, sw, font_xs, TEXT_GRAY); y += int(44*s)
        packages = [
            ("250 Kredi","₺99","~10 görsel üretimi",False),
            ("750 Kredi","₺249","~30 görsel üretimi",True),
            ("2.500 Kredi","₺749","~100 görsel üretimi",False),
            ("7.000 Kredi","₺1.799","~280 görsel üretimi",False),
        ]
        for name, price, usage, pop in packages:
            h_c = int(110*s) if pop else int(96*s)
            bg = blend(BG_CARD, accent, 0.10) if pop else BG_CARD
            draw_card(draw, sx+int(8*s), y, sw-int(16*s), h_c, fill=bg, border=accent if pop else BORDER)
            if pop:
                draw_pill(draw, sx+sw-int(150*s), y+int(8*s), "🏆 En Popüler", font_xs, accent, pad_x=8, pad_h=4)
            draw.text((sx+int(20*s), y+int(12*s)), name, font=font_mb, fill=TEXT_WHITE)
            draw.text((sx+int(20*s), y+int(48*s)), price, font=font_m, fill=accent)
            draw.text((sx+int(20*s), y+int(76*s)), usage, font=font_xs, fill=TEXT_GRAY)
            y += h_c + int(12*s)
        y += int(8*s)
        draw.text((sx+int(20*s), y), "🔒 App Store ile güvenli ödeme", font=font_xs, fill=TEXT_GRAY)
        y += int(28*s)
        draw.text((sx+int(20*s), y), "📱 Krediler hesabınıza anında yüklenir", font=font_xs, fill=TEXT_GRAY)

    elif screen_idx == 5:  # Tema / Ayarlar
        text_center(draw, "✨ Kişiselleştir", sx, y, sw, font_m, TEXT_WHITE); y += int(50*s)
        themes = [("🌙","Koyu Mod",True), ("☀️","Açık Mod",False), ("⚙️","Sistem",False)]
        for ico, name, sel in themes:
            col = accent if sel else BORDER
            px = sx + int(8*s) + themes.index((ico, name, sel)) * int((sw-int(32*s))//3 + int(8*s))
            draw_card(draw, px, y, int((sw-int(32*s))//3), int(70*s), fill=blend(BG_CARD, accent, 0.10) if sel else BG_CARD, border=col)
            draw.text((px+int(14*s), y+int(8*s)), ico, font=font_m, fill=col)
            draw.text((px+int(10*s), y+int(44*s)), name, font=font_xs, fill=TEXT_WHITE if sel else TEXT_GRAY)
        y += int(88*s)
        langs = [("🇹🇷","Türkçe",True),("🇺🇸","English",False),("🇩🇪","Deutsch",False),("🇫🇷","Français",False),("🇸🇦","العربية",False),("🇷🇺","Русский",False)]
        draw.text((sx+int(16*s), y), "Dil Seçimi", font=font_s, fill=TEXT_GRAY); y += int(40*s)
        for i, (flag, name, sel) in enumerate(langs):
            row, col2 = i // 2, i % 2
            px = sx + int(8*s) + col2 * ((sw-int(32*s))//2 + int(8*s))
            py = y + row * int(66*s)
            col = accent if sel else BORDER
            draw_card(draw, px, py, (sw-int(32*s))//2, int(58*s), fill=blend(BG_CARD, accent, 0.08) if sel else BG_CARD, border=col)
            draw.text((px+int(12*s), py+int(10*s)), flag+" "+name, font=font_s, fill=TEXT_WHITE if sel else TEXT_GRAY)


# ─── Ana üretim fonksiyonu ───────────────────────────────────────────────────

def make_screenshot(w, h, title, subtitle, screen_fn, accent, arabic=False, caption_bottom=True):
    img = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(img)
    draw_bg(img, w, h, accent)

    s = w / 1290.0  # ölçek faktörü

    # Caption - üst bölge
    cap_h = int(360 * s)
    font_title = load_font(int(76*s), arabic=arabic)
    font_sub   = load_font(int(36*s), bold=False, arabic=arabic)

    # Başlık — dikey ortalanmış
    lines = title.split('\n')
    line_h = int(84*s)
    total_title_h = len(lines) * line_h
    ty = int(70*s) + (cap_h - total_title_h - int(50*s)) // 4

    for line in lines:
        text_center(draw, line, 0, ty, w, font_title, TEXT_WHITE)
        ty += line_h

    # Alt başlık
    ty += int(12*s)
    sub_lines = subtitle.split('\n')
    for sl in sub_lines:
        text_center(draw, sl, 0, ty, w, font_sub, TEXT_GRAY)
        ty += int(48*s)

    # Telefon çerçevesi
    fw = int(w * 0.72)
    fh = int(h * 0.58)
    fx = (w - fw) // 2
    fy = cap_h + int(20*s)

    # Basit iPhone frame
    fr = int(fw * 0.09)
    # Dış gölge
    for si in range(15, 0, -1):
        alpha_val = int((15-si)/15 * 60)
        shadow_col = tuple(int(c * (1 - (15-si)/15 * 0.3)) for c in BG_DARK)
        draw.rounded_rectangle([fx-si, fy-si, fx+fw+si, fy+fh+si], radius=fr+si,
                                fill=shadow_col, outline=None)

    frame_fill = (24, 32, 50)
    draw.rounded_rectangle([fx, fy, fx+fw, fy+fh], radius=fr, fill=frame_fill, outline=(55,70,100), width=int(4*s))

    margin = int(fw * 0.045)
    sx_s = fx + margin; sy_s = fy + margin
    sw_s = fw - margin*2; sh_s = fh - margin*2
    sr = max(fr - margin, 12)
    draw.rounded_rectangle([sx_s, sy_s, sx_s+sw_s, sy_s+sh_s], radius=sr, fill=BG_SCREEN)

    # Notch
    ni_w = int(sw_s * 0.3); ni_h = int(26*s)
    ni_x = sx_s + (sw_s - ni_w) // 2; ni_y = sy_s + int(18*s)
    draw.rounded_rectangle([ni_x, ni_y, ni_x+ni_w, ni_y+ni_h], radius=int(13*s), fill=(8, 12, 22))

    # Durum çubuğu
    st_font = load_font(int(20*s))
    st_y = ni_y + ni_h + int(10*s)
    draw.text((sx_s + int(20*s), st_y), "9:41", font=st_font, fill=TEXT_LIGHT)
    draw.text((sx_s + sw_s - int(80*s), st_y), "●●◌", font=st_font, fill=TEXT_LIGHT)

    # Ekran içeriği
    content_y = st_y + int(35*s)
    screen_fn(draw, sx_s, content_y, sw_s, sh_s, s)

    # Home indicator (alt çizgi)
    hi_w = int(sw_s * 0.35)
    hi_x = sx_s + (sw_s - hi_w) // 2
    hi_y = sy_s + sh_s - int(20*s)
    draw.rounded_rectangle([hi_x, hi_y, hi_x+hi_w, hi_y+int(5*s)], radius=3, fill=(60,75,100))

    # Alt Accent şeridi
    stripe_y = fy + fh + int(24*s)
    stripe_h = int(6*s)
    for si in range(stripe_h):
        t = si / stripe_h
        col = blend(accent, tuple(int(c*0.3) for c in accent), t)
        draw.line([(fx, stripe_y+si), (fx+fw, stripe_y+si)], fill=col)

    # App badge (sol üst)
    badge_font = load_font(int(24*s))
    draw.text((int(50*s), int(50*s)), "iOS", font=badge_font, fill=TEXT_GRAY)

    return img


def generate_all(app_name, out_dir):
    out_dir = Path(out_dir)

    if app_name in ("panel", "all"):
        for size_label, (w, h) in SIZES.items():
            if size_label not in PRIMARY_SIZES: continue
            for lang in ("tr", "en"):
                lang_asc = "tr-TR" if lang == "tr" else "en-US"
                d = out_dir / "nickdegs-panel" / lang_asc / size_label
                d.mkdir(parents=True, exist_ok=True)
                for idx, (fname, title_tr, title_en, sub_tr, sub_en) in enumerate(PANEL_SCREENS):
                    title = title_tr if lang == "tr" else title_en
                    subtitle = sub_tr if lang == "tr" else sub_en
                    def content_fn(draw, sx, sy, sw, sh, s, _idx=idx):
                        draw_panel_screen(draw, sx, sy, sw, sh, _idx, PANEL_ACCENT, s)
                    img = make_screenshot(w, h, title, subtitle, content_fn, PANEL_ACCENT)
                    out = d / f"{fname}.png"
                    img.save(str(out), "PNG", optimize=True)
                    print(f"  panel/{lang_asc}/{size_label}/{fname}.png")

    if app_name in ("business", "all"):
        langs_b = list(BUSINESS_SCREENS.keys())
        lang_map = {"tr":"tr-TR","en":"en-US","de":"de-DE","fr":"fr-FR","es":"es-ES"}
        for size_label, (w, h) in SIZES.items():
            if size_label not in PRIMARY_SIZES: continue
            for lang in langs_b:
                lang_asc = lang_map[lang]
                screens = BUSINESS_SCREENS[lang]
                d = out_dir / "nickdegs-business" / lang_asc / size_label
                d.mkdir(parents=True, exist_ok=True)
                for idx, (fname, title, subtitle) in enumerate(screens):
                    def content_fn(draw, sx, sy, sw, sh, s, _idx=idx, _title=title, _sub=subtitle):
                        draw_business_screen(draw, sx, sy, sw, sh, _idx, _title, _sub, BUSINESS_ACCENT, s)
                    img = make_screenshot(w, h, title, subtitle, content_fn, BUSINESS_ACCENT)
                    out = d / f"{fname}.png"
                    img.save(str(out), "PNG", optimize=True)
                    print(f"  business/{lang_asc}/{size_label}/{fname}.png")

    if app_name in ("rv", "all"):
        lang_map = {"tr":"tr-TR","en":"en-US","de":"de-DE","fr":"fr-FR","es":"es-ES","ar":"ar-SA","ru":"ru"}
        for size_label, (w, h) in SIZES.items():
            if size_label not in PRIMARY_SIZES: continue
            for lang in RV_SCREENS.keys():
                lang_asc = lang_map[lang]
                screens = RV_SCREENS[lang]
                arabic = (lang == "ar")
                d = out_dir / "realvirtuality-ai" / lang_asc / size_label
                d.mkdir(parents=True, exist_ok=True)
                for idx, (fname, title, subtitle) in enumerate(screens):
                    def content_fn(draw, sx, sy, sw, sh, s, _idx=idx, _ar=arabic):
                        draw_rv_screen(draw, sx, sy, sw, sh, _idx, RV_ACCENT, s, _ar)
                    img = make_screenshot(w, h, title, subtitle, content_fn, RV_ACCENT, arabic=arabic)
                    out = d / f"{fname}.png"
                    img.save(str(out), "PNG", optimize=True)
                    print(f"  rv/{lang_asc}/{size_label}/{fname}.png")

    print("\n✅ Tüm ekran görüntüleri oluşturuldu →", out_dir)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--app", default="all", choices=["all","panel","business","rv"])
    p.add_argument("--out", default="/opt/mobil-uygulamalar/screenshots")
    args = p.parse_args()
    generate_all(args.app, args.out)
