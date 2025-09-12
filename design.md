# Tasarım — FocusGuard Study (Dikkat Takibi)

## Akış
1) Launch → Auth (Kayıt/Giriş)
2) Home → "Ders Çalış" (primary), "Raporlarım", "Ayarlar"
3) Mod Seçimi → Sadece Kitap / Sadece Telefon / Hibrit
4) Çalışma Ekranı → Sol: Kamera/Overlay (genişliğin 3/5'i), Sağ: Panel (2/5)
5) Bitir → Oturumu Firestore'a yaz → Başarı/özet → Home
6) Raporlarım → Gün seç, detayları ve grafikleri gör → Günleri karşılaştır

## Ekranlar & Bileşenler

### Auth (Login/Signup)
- E-posta, Şifre alanları (form validation)
- "Hesap oluştur" / "Giriş yap" toggle
- Başarılıysa Home'a yönlendir

### Home
- Büyük CTA: "Ders Çalış"
- Secondary: "Raporlarım", küçük: "Ayarlar"
- Kullanıcı adı/eposta gösterimi (Firebase Auth currentUser)

### Mod Seçimi
- 3 kart: Sadece Kitap / Sadece Telefon / Hibrit
- Her kartta kısa açıklama

### Çalışma Ekranı
- Layout: Row
  - Left (flex 3): Kamera + gaze overlay (portrait)
  - Right (flex 2):
    - Oturum süresi (timer)
    - Odak yüzdesi (focusRatio)
    - Dikkat dağılım sayısı (distractCount)
    - Anlık durum göstergesi (Focused/Drifting)
    - Butonlar: Duraklat/Sürdür, Bitir
    - Uyarı alanı (>=10 sn dışarı bakışta modal/snackbar)

### Raporlarım
- Gün seçici (takvim/scroll list)
- Günlük özet: toplam süre, odak %, uyarı sayısı
- Grafikler:
  - Zaman serisi: odak/dikkat durumu (sparkline)
  - Gün karşılaştırma: sütun/çizgi

## Dikkat Algoritması — İlk Sürüm
- Kaynak: `GazeFrame { x, y, conf, valid, ts }` (+ iOS TODO: `headPitch`)
- Eşikler:
  - conf >= 0.5 varsayılan kabul
  - Telefon modu: (x,y) in [0..1] içinde → focused; değilse drifting
  - Kitap modu: headPitch < thresholdDown → focused; değilse drifting (TODO: iOS expose)
  - Hibrit: Telefon OR Kitap focused → focused; aksi drifting
- Kural: drifting-state toplam süresi ≥ 10s ise uyarı göster ve sayaç +1
- Filtre: 1-Euro filtre çıkışını kullan; state jitter'ını azaltmak için 500ms debouncing

## Veri Modeli (Firestore)
- `users/{uid}`: profil ve ayarlar (isteğe bağlı)
- `users/{uid}/sessions/{sessionId}`:
  - startTs, endTs, mode, focusRatio, distractCount
  - events: [{ ts, type: "warning"|"pause"|"resume" }]
  - params: filter/mincutoff, beta, calibVersion

## Teknik Notlar
- Orientation: İlk sürüm portrait. Landscape TODO.
- iOS: `GazeProvider.swift` içine head euler/pitch ekle → MethodChannel payload'ına dahil et (TODO-M2).
- Performans: Frame başı tek invoke, gerekirse throttle.
- Erişilebilirlik: Uyarılarda ses/titreşim toggle (Ayarlar)
