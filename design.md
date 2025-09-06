# Tasarım — UI/UX

## Ekranlar
1) **Home**
   - Başlık: "FocusGuard Gaze"
   - Butonlar: [Start], [Stop], [Calibration], [Overlay On/Off]
   - Küçük metrikler: valid?, conf, fps

2) **Calibration (Wizard)**
   - 3×3 grid hedefler (9 nokta)
   - Her hedefte: kullanıcı hedefe bakarken 0.5 sn örnekle → ortalamasını al → kaydet
   - Sonunda: afine fit hesaplanır, başarı mesajı

3) **Overlay**
   - Tam ekran üstünde top (default radius ~10–14 dp)
   - Validity=false ise top gizlenir
   - Filtre sonrası koordinat uygulanır

## Görsel Stil
- Sade, açık tema.
- Top için opak daire + hafif dış glow (GPU ucuz).
- Değerler için küçük monospaced label.

## Davranış
- Start → AR başlar, onFrame akar, overlay görünür.
- Stop → AR durur, overlay gizlenir.
- Calibration → wizard; bittiğinde dönüşüm devreye girer.
