#!/usr/bin/env python3
"""Generates backend/src/main/resources/db/seed-dev/R__dev_seed.sql.

DEVELOPMENT DATA ONLY: invented catalog, prices, stock and demo accounts. It is only loaded by the `dev` profile
(spring.flyway.locations includes classpath:db/seed-dev) and must never run against production.
No reviews, ratings, sales counts or customer statistics are invented.
"""
import json
import os
import uuid

NS = uuid.UUID("feb7a000-0000-4000-8000-000000000000")


def uid(name):
    return str(uuid.uuid5(NS, name))


def q(s):
    return "'" + str(s).replace("'", "''") + "'"


def j(obj):
    return q(json.dumps(obj, ensure_ascii=False)) + "::jsonb"


def tr(ru, kk, en):
    return {"ru": ru, "kk": kk, "en": en}


VARIANT_LABELS = {
    "SMALL": tr("Малый", "Шағын", "Small"),
    "STANDARD": tr("Стандартный", "Стандартты", "Standard"),
    "LARGE": tr("Большой", "Үлкен", "Large"),
    "PREMIUM": tr("Премиум", "Премиум", "Premium"),
}

CATEGORIES = [
    ("roses", tr("Розы", "Раушандар", "Roses"), 1),
    ("peonies", tr("Пионы", "Пиондар", "Peonies"), 2),
    ("tulips", tr("Тюльпаны", "Қызғалдақтар", "Tulips"), 3),
    ("mixed", tr("Смешанные", "Аралас букеттер", "Mixed bouquets"), 4),
    ("premium", tr("Премиум", "Премиум букеттер", "Premium bouquets"), 5),
    ("gifts", tr("Подарки", "Сыйлықтар", "Gifts"), 6),
    ("seasonal", tr("Сезонные", "Маусымдық гүлдер", "Seasonal flowers"), 7),
]

# slug, category, names, description, composition, featured, seasonal, gift, prep, variants[(code, price, stems)], stock
PRODUCTS = [
    ("nezhnost", "mixed", tr("Нежность", "Нәзіктік", "Tenderness"),
     tr("Воздушный букет из розовых роз и пионовидных роз в сливовой упаковке. Мягкие оттенки для самых тёплых слов.",
        "Қызғылт раушандар мен пион тәрізді раушандардан жасалған жеңіл букет. Ең жылы сөздерге арналған жұмсақ реңктер.",
        "An airy bouquet of pink roses and peony-style roses in plum wrapping. Soft shades for the warmest words."),
     tr("Роза, пионовидная роза, гипсофила, эвкалипт", "Раушан, пион тәрізді раушан, гипсофила, эвкалипт", "Rose, peony rose, gypsophila, eucalyptus"),
     True, False, False, 90,
     [("SMALL", 14900, 9), ("STANDARD", 21900, 15), ("LARGE", 32900, 25), ("PREMIUM", 48900, 35)], (12, 6)),
    ("magiya-chuvstv", "mixed", tr("Магия чувств", "Сезім сиқыры", "Magic of Feelings"),
     tr("Роскошный букет из розовых пионов, роз и кустовых роз с ароматным эвкалиптом. Ярко, нежно и запоминающе.",
        "Қызғылт пиондар, раушандар және бұта раушандарынан тұратын сәнді букет. Жарқын, нәзік және есте қаларлық.",
        "A lavish bouquet of pink peonies, roses and spray roses with fragrant eucalyptus. Bright, tender, memorable."),
     tr("Пионы, розы, кустовые розы, эвкалипт", "Пиондар, раушандар, бұта раушандары, эвкалипт", "Peonies, roses, spray roses, eucalyptus"),
     True, False, False, 90,
     [("SMALL", 15900, 9), ("STANDARD", 23900, 15), ("LARGE", 35900, 25), ("PREMIUM", 52900, 35)], (10, 5)),
    ("vdohnovenie", "mixed", tr("Вдохновение", "Шабыт", "Inspiration"),
     tr("Тёплый букет в персиковых и коралловых тонах для солнечного настроения.",
        "Күн сәулелі көңіл-күйге арналған шабдалы және маржан түстес жылы букет.",
        "A warm bouquet in peach and coral tones for a sunny mood."),
     tr("Роза, ранункулюс, фисташка", "Раушан, ранункулюс, фисташка жапырағы", "Rose, ranunculus, pistachio foliage"),
     False, False, False, 90,
     [("SMALL", 13900, 9), ("STANDARD", 19900, 15), ("LARGE", 29900, 25)], (8, 4)),
    ("romantika", "roses", tr("Романтика", "Романтика", "Romance"),
     tr("Классические красные розы в чёрной упаковке — жест, который не нуждается в объяснениях.",
        "Қара орамадағы классикалық қызыл раушандар — түсіндіруді қажет етпейтін ым.",
        "Classic red roses in black wrapping — a gesture that needs no explanation."),
     tr("Красная роза, рускус", "Қызыл раушан, рускус", "Red rose, ruscus"),
     True, False, False, 75,
     [("SMALL", 12900, 11), ("STANDARD", 21900, 21), ("LARGE", 38900, 35), ("PREMIUM", 62900, 51)], (20, 10)),
    ("pionovoe-oblako", "peonies", tr("Пионовое облако", "Пион бұлты", "Peony Cloud"),
     tr("Нежно-розовые пионы, собранные в пышное облако. Сезонный и очень ароматный букет.",
        "Пышный бұлт болып жиналған ақшыл қызғылт пиондар. Маусымдық әрі өте хош иісті букет.",
        "Soft pink peonies gathered into a lush cloud. A seasonal, deeply fragrant bouquet."),
     tr("Пион", "Пион", "Peony"),
     True, True, False, 120,
     [("SMALL", 17900, 7), ("STANDARD", 27900, 11), ("LARGE", 41900, 17)], (6, 3)),
    ("belaya-klassika", "roses", tr("Белая классика", "Ақ классика", "White Classic"),
     tr("Белые розы и воздушная гипсофила в светлой упаковке. Чистота и элегантность.",
        "Ашық орамадағы ақ раушандар мен жеңіл гипсофила. Тазалық пен талғам.",
        "White roses and airy gypsophila in light wrapping. Purity and elegance."),
     tr("Белая роза, гипсофила", "Ақ раушан, гипсофила", "White rose, gypsophila"),
     False, False, False, 75,
     [("SMALL", 13900, 9), ("STANDARD", 20900, 15), ("LARGE", 31900, 25)], (14, 0)),
    ("tyulpany-vesennie", "tulips", tr("Тюльпаны весенние", "Көктемгі қызғалдақтар", "Spring Tulips"),
     tr("Разноцветные тюльпаны — свежий и радостный букет, как первый тёплый день.",
        "Түрлі-түсті қызғалдақтар — алғашқы жылы күн сияқты балғын әрі қуанышты букет.",
        "Multicoloured tulips — a fresh, joyful bouquet like the first warm day."),
     tr("Тюльпан", "Қызғалдақ", "Tulip"),
     False, True, False, 60,
     [("SMALL", 9900, 15), ("STANDARD", 15900, 25), ("LARGE", 24900, 45)], (25, 12)),
    ("lavandovyj-son", "mixed", tr("Лавандовый сон", "Лаванда түсі", "Lavender Dream"),
     tr("Сиреневые розы и эвкалипт — спокойный букет с глубоким, мечтательным настроением.",
        "Көгілдір-күлгін раушандар мен эвкалипт — терең, арманшыл көңіл-күйдегі тыныш букет.",
        "Lilac roses with eucalyptus — a calm bouquet with a deep, dreamy mood."),
     tr("Сиреневая роза, эвкалипт, статица", "Көгілдір раушан, эвкалипт, статица", "Lilac rose, eucalyptus, statice"),
     False, False, False, 90,
     [("SMALL", 14900, 9), ("STANDARD", 22900, 15), ("LARGE", 33900, 25)], (7, 3)),
    ("alyj-barhat", "premium", tr("Алый бархат", "Қызыл барқыт", "Scarlet Velvet"),
     tr("Бархатные тёмно-красные розы премиум-класса. Впечатляющий подарок для особого случая.",
        "Премиум сыныпты барқыт қою қызыл раушандар. Ерекше сәтке әсерлі сыйлық.",
        "Premium velvety deep-red roses. An impressive gift for a special occasion."),
     tr("Роза премиум 60 см", "Премиум раушан 60 см", "Premium rose 60 cm"),
     True, False, False, 90,
     [("STANDARD", 54900, 25), ("LARGE", 89900, 51), ("PREMIUM", 149900, 101)], (6, 2)),
    ("sad-fei", "mixed", tr("Сад феи", "Перілер бағы", "Fairy Garden"),
     tr("Сказочный микс роз, тюльпанов и пионов в пастельной гамме с гипсофилой.",
        "Гипсофилалы пастельді гаммадағы раушандар, қызғалдақтар және пиондардың ертегідей қоспасы.",
        "A fairy-tale mix of roses, tulips and peonies in a pastel palette with gypsophila."),
     tr("Роза, пион, тюльпан, гипсофила", "Раушан, пион, қызғалдақ, гипсофила", "Rose, peony, tulip, gypsophila"),
     True, False, True, 100,
     [("STANDARD", 25900, 19), ("LARGE", 38900, 31), ("PREMIUM", 57900, 45)], (9, 4)),
    ("korolevskij-pion", "premium", tr("Королевский пион", "Патша пионы", "Royal Peony"),
     tr("Крупные насыщенно-розовые пионы — роскошь в каждом бутоне. Количество ограничено сезоном.",
        "Iрі қою қызғылт пиондар — әр бүршіктегі сән. Саны маусыммен шектелген.",
        "Large deep-pink peonies — luxury in every bloom. Quantity is limited by the season."),
     tr("Пион премиум", "Премиум пион", "Premium peony"),
     False, True, False, 120,
     [("STANDARD", 39900, 11), ("LARGE", 62900, 19), ("PREMIUM", 94900, 29)], (5, 0)),
    ("podarochnyj-mini", "gifts", tr("Подарочный мини-букет", "Сыйлық мини-букет", "Gift Mini Bouquet"),
     tr("Компактный букет в подарочной упаковке — отличный повод сказать «спасибо» или «я думаю о тебе».",
        "Сыйлық орамасындағы шағын букет — «рахмет» немесе «сен туралы ойлаймын» деуге тамаша себеп.",
        "A compact gift-wrapped bouquet — a lovely way to say “thank you” or “I’m thinking of you”."),
     tr("Кустовая роза, гипсофила", "Бұта раушаны, гипсофила", "Spray rose, gypsophila"),
     False, False, True, 60,
     [("SMALL", 7900, 5), ("STANDARD", 11900, 9)], (15, 8)),
    ("vesennij-miks", "seasonal", tr("Весенний микс", "Көктемгі микс", "Spring Mix"),
     tr("Яркий сезонный букет из тюльпанов, роз и свежей зелени.",
        "Қызғалдақтар, раушандар және жаңа жасыл өсімдіктерден жасалған жарқын маусымдық букет.",
        "A bright seasonal bouquet of tulips, roses and fresh greenery."),
     tr("Тюльпан, роза, зелень", "Қызғалдақ, раушан, жасыл өсімдіктер", "Tulip, rose, greenery"),
     False, True, False, 75,
     [("SMALL", 11900, 11), ("STANDARD", 17900, 19), ("LARGE", 26900, 31)], (11, 6)),
    ("osennyaya-simfoniya", "seasonal", tr("Осенняя симфония", "Күзгі симфония", "Autumn Symphony"),
     tr("Бордовые и тёплые золотистые оттенки — букет в духе осеннего заката.",
        "Қызыл күрең және жылы алтындай реңктер — күз кешін еске түсіретін букет.",
        "Burgundy and warm golden shades — a bouquet inspired by an autumn sunset."),
     tr("Роза, ранункулюс, сухоцветы", "Раушан, ранункулюс, құрғақ гүлдер", "Rose, ranunculus, dried flowers"),
     False, True, False, 90,
     [("STANDARD", 21900, 15), ("LARGE", 33900, 25)], (0, 0)),
    ("korallovyj-rassvet", "peonies", tr("Коралловый рассвет", "Маржан таң", "Coral Dawn"),
     tr("Коралловые пионы с нежными розами — тёплый букет, похожий на рассвет.",
        "Нәзік раушандармен үйлескен маржан пиондар — таңға ұқсас жылы букет.",
        "Coral peonies with tender roses — a warm bouquet reminiscent of dawn."),
     tr("Пион, роза", "Пион, раушан", "Peony, rose"),
     False, True, False, 120,
     [("STANDARD", 29900, 11), ("LARGE", 44900, 17)], (4, 2)),
    ("rozy-ekvador-25", "roses", tr("Розы «Эквадор» 25", "«Эквадор» раушандары 25", "Ecuador Roses 25"),
     tr("25 длинных эквадорских роз с крупным бутоном. Классика, которая всегда уместна.",
        "Iрі бүршікті 25 ұзын эквадор раушаны. Әрқашан орынды классика.",
        "25 long Ecuadorian roses with large blooms. A classic that is always appropriate."),
     tr("Эквадорская роза 70 см", "Эквадор раушаны 70 см", "Ecuadorian rose 70 cm"),
     False, False, False, 90,
     [("STANDARD", 47900, 25), ("LARGE", 79900, 51)], (8, 4)),
]


def build():
    out = []
    w = out.append
    w("-- GENERATED by tools/generate_seed.py. DEVELOPMENT DATA ONLY (dev profile). Idempotent.")
    # zones
    z1, z2 = uid("zone-center"), uid("zone-city")
    aliases = "алматы,almaty,алмаата,алмата"
    w(f"""INSERT INTO delivery_zones (id, code, city_code, city_aliases, name, center_lat, center_lng, radius_km, base_fee,
    free_delivery_threshold, asap_enabled, asap_fee, asap_eta_minutes, work_start, work_end, is_default, active) VALUES
 ({q(z1)}, 'almaty-center', 'almaty', {q(aliases)}, {j(tr('Алматы — центр', 'Алматы — орталық', 'Almaty — centre'))}, 43.238900, 76.945500, 7, 1500, 25000, true, 1500, 90, '09:00', '21:00', true, true),
 ({q(z2)}, 'almaty-city', 'almaty', {q(aliases)}, {j(tr('Алматы — весь город', 'Алматы — бүкіл қала', 'Almaty — whole city'))}, 43.238900, 76.945500, 30, 2500, 40000, false, 0, 120, '09:00', '21:00', false, true)
ON CONFLICT (id) DO NOTHING;""")

    def slots(zone, rows, cutoff, cap):
        for i, (s, e, sur) in enumerate(rows):
            sid = uid(f"slot-{zone}-{s}")
            w(f"INSERT INTO delivery_slot_templates (id, zone_id, start_time, end_time, capacity, cutoff_minutes, surcharge) "
              f"VALUES ({q(sid)}, {q(zone)}, '{s}', '{e}', {cap}, {cutoff}, {sur}) ON CONFLICT (id) DO NOTHING;")

    slots(z1, [("10:00", "12:00", 0), ("12:00", "14:00", 0), ("14:00", "16:00", 0), ("16:00", "18:00", 0), ("18:00", "20:00", 500)], 120, 6)
    slots(z2, [("12:00", "14:00", 0), ("16:00", "18:00", 0), ("18:00", "20:00", 500)], 180, 4)

    # florists
    f1, f2 = uid("florist-dostyk"), uid("florist-samal")
    w(f"""INSERT INTO florists (id, name, city, address, phone, priority, active) VALUES
 ({q(f1)}, 'FEYA Studio Достык', 'Алматы', 'пр. Достык, 100 (демо-адрес)', '+77270000001', 10, true),
 ({q(f2)}, 'FEYA Studio Самал', 'Алматы', 'мкр. Самал-2, 20 (демо-адрес)', '+77270000002', 20, true)
ON CONFLICT (id) DO NOTHING;""")
    w(f"INSERT INTO florist_zones (florist_id, zone_id) VALUES ({q(f1)}, {q(z1)}), ({q(f1)}, {q(z2)}), ({q(f2)}, {q(z1)}) ON CONFLICT DO NOTHING;")

    # categories
    cat_ids = {}
    for slug, name, order in CATEGORIES:
        cid = uid("cat-" + slug)
        cat_ids[slug] = cid
        w(f"INSERT INTO categories (id, slug, name, sort_order, active) VALUES ({q(cid)}, {q(slug)}, {j(name)}, {order}, true) ON CONFLICT (id) DO NOTHING;")

    # products
    for pslug, cat, name, desc, comp, featured, seasonal, gift, prep, variants, stock in PRODUCTS:
        pid = uid("prod-" + pslug)
        price_from = min(v[1] for v in variants)
        search = " ".join([pslug] + [v.lower() for v in name.values()] + [v.lower() for v in desc.values()])
        w(f"""INSERT INTO products (id, slug, category_id, name, description, composition, search_text, price_from, featured, seasonal, gift, prep_minutes, active)
VALUES ({q(pid)}, {q(pslug)}, {q(cat_ids[cat])}, {j(name)}, {j(desc)}, {j(comp)}, {q(search)}, {price_from}, {str(featured).lower()}, {str(seasonal).lower()}, {str(gift).lower()}, {prep}, true) ON CONFLICT (id) DO NOTHING;""")
        for n in (1, 2):
            w(f"INSERT INTO product_images (id, product_id, url, alt, sort_order) VALUES ({q(uid(f'img-{pslug}-{n}'))}, {q(pid)}, '/media/bouquets/{pslug}-{n}.jpg', {q(name['ru'])}, {n - 1}) ON CONFLICT (id) DO NOTHING;")
        order = {"SMALL": 0, "STANDARD": 1, "LARGE": 2, "PREMIUM": 3}
        for code, price, stems in variants:
            vid = uid(f"var-{pslug}-{code}")
            w(f"INSERT INTO product_variants (id, product_id, code, label, price, stems_count, sort_order, active) VALUES ({q(vid)}, {q(pid)}, '{code}', {j(VARIANT_LABELS[code])}, {price}, {stems}, {order[code]}, true) ON CONFLICT (id) DO NOTHING;")
            q1, q2 = stock
            # Larger variants are scarcer; premium variants are stocked in a single shop only.
            f1q = max(0, q1 - 2 * order[code]) if q1 else 0
            f2q = max(0, q2 - 2 * order[code]) if q2 and code != "PREMIUM" else 0
            if pslug == "alyj-barhat" and code == "PREMIUM":
                f1q, f2q = 2, 0
            if f1q:
                w(f"INSERT INTO inventory (id, florist_id, variant_id, quantity) VALUES ({q(uid(f'inv1-{pslug}-{code}'))}, {q(f1)}, {q(vid)}, {f1q}) ON CONFLICT (id) DO NOTHING;")
            if f2q:
                w(f"INSERT INTO inventory (id, florist_id, variant_id, quantity) VALUES ({q(uid(f'inv2-{pslug}-{code}'))}, {q(f2)}, {q(vid)}, {f2q}) ON CONFLICT (id) DO NOTHING;")

    # promo codes
    w(f"""INSERT INTO promo_codes (id, code, type, value, min_order, max_discount, valid_until, per_user_limit, active) VALUES
 ({q(uid('promo-feya10'))}, 'FEYA10', 'PERCENT', 10, 10000, 5000, NULL, NULL, true),
 ({q(uid('promo-welcome'))}, 'WELCOME2000', 'FIXED', 2000, 15000, NULL, NULL, 1, true),
 ({q(uid('promo-expired'))}, 'EXPIRED', 'PERCENT', 20, 0, NULL, '2020-01-01T00:00:00Z', NULL, true)
ON CONFLICT (id) DO NOTHING;""")

    # banners
    banners = [
        ("banner-spring", tr("Весна с FEYA", "FEYA-мен көктем", "Spring with FEYA"), tr("−10% на первый заказ по промокоду FEYA10", "FEYA10 промокоды бойынша алғашқы тапсырысқа −10%", "−10% off your first order with code FEYA10"), "FEYA10", "category", "mixed", 1),
        ("banner-peony", tr("Сезон пионов", "Пион маусымы", "Peony season"), tr("Нежные пионы с доставкой за 2 часа", "2 сағат ішінде жеткізілетін нәзік пиондар", "Tender peonies delivered within 2 hours"), None, "category", "peonies", 2),
        ("banner-gifts", tr("Подарки к любому поводу", "Кез келген іске сыйлық", "Gifts for any occasion"), tr("Мини-букеты от 7 900 ₸", "7 900 ₸-ден мини-букеттер", "Mini bouquets from 7,900 ₸"), None, "category", "gifts", 3),
    ]
    for key, title, sub, promo, ttype, tvalue, order in banners:
        w(f"INSERT INTO banners (id, title, subtitle, image_url, promo_code, target_type, target_value, sort_order, active) VALUES ({q(uid(key))}, {j(title)}, {j(sub)}, '/media/banners/{key}.jpg', {q(promo) if promo else 'NULL'}, {q(ttype)}, {q(tvalue)}, {order}, true) ON CONFLICT (id) DO NOTHING;")

    # demo accounts (phone OTP login; dev OTP is returned by the API in the dev profile)
    users = [
        ("admin", "+77000000001", "Админ FEYA", ["ADMIN"], None),
        ("florist1", "+77000000002", "Флорист Достык", ["FLORIST"], f1),
        ("courier1", "+77000000003", "Алексей К.", ["COURIER"], None),
        ("support", "+77000000004", "Поддержка FEYA", ["SUPPORT"], None),
        ("florist2", "+77000000005", "Флорист Самал", ["FLORIST"], f2),
        ("customer", "+77010000000", "Анна Иванова", [], None),
    ]
    for key, phone, name, roles, fid in users:
        u = uid("user-" + key)
        w(f"INSERT INTO users (id, phone, name, language, florist_id) VALUES ({q(u)}, {q(phone)}, {q(name)}, 'ru', {q(fid) if fid else 'NULL'}) ON CONFLICT (phone) DO NOTHING;")
        for r in ["CUSTOMER"] + roles:
            w(f"INSERT INTO user_roles (user_id, role) SELECT id, '{r}' FROM users WHERE phone = {q(phone)} ON CONFLICT DO NOTHING;")
    w(f"INSERT INTO couriers (user_id, vehicle, active) SELECT id, 'Электросамокат', true FROM users WHERE phone = '+77000000003' ON CONFLICT DO NOTHING;")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    target = os.path.join(os.path.dirname(__file__), "..", "backend", "src", "main", "resources", "db", "seed-dev", "R__dev_seed.sql")
    with open(target, "w", encoding="utf-8") as f:
        f.write(build())
    print("written", os.path.abspath(target))
