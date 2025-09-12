# FocusGuard Study — Öğrenciler için Dikkat Takibi

FocusGuard Study, iOS (ARKit + TrueDepth) tabanlı bakış tahmini ile öğrencilerin ders çalışma sırasında dikkat durumlarını izleyen ve dikkat dağıldığında uyaran bir uygulamadır. Verileri Firebase'e kaydeder, günlük raporlar ve grafiklerle ilerlemeyi gösterir.

## 🎯 Çekirdek Özellikler
- **E-posta ile Kayıt/Giriş** (Firebase Auth)
- **Ders Modları**: Sadece Kitap, Sadece Telefon, Hibrit
- **Dikkat Kuralı**: Dikkat ekran/kitap dışına kayıp 10 sn sürerse uyarı
- **Bakış Tahmini**: iOS TrueDepth + ARKit ile, 1-Euro filtre ve kalibrasyon
- **Oturum Kayıtları**: Süre, odak yüzdesi, dikkat dağılma sayısı, uyarılar (Firestore)
- **Raporlarım**: Günlük görünüm, gün karşılaştırma, grafikler

## 📱 Ekranlar
- **Giriş/Kayıt**: E-posta/şifre ile hesap oluşturma ve giriş
- **Ana**: Tek bir büyük buton — "Ders Çalış"; ayrıca "Raporlarım" ve "Ayarlar"
- **Mod Seçimi**: Sadece Kitap / Sadece Telefon / Hibrit
- **Çalışma**: Sol 3/5 kamera/overlay, sağ 2/5 panel (süre, odak %, uyarılar, duraklat/bitir)
- **Raporlarım**: Gün listesi, gün karşılaştırma, çizgi/sütun grafikler

## 🔎 Dikkat Mantığı (ilk sürüm)
- **Genel**: `valid=false` veya bakış ekran/kitap bölgesi dışında belirgin şekildeyse → "dışarı bakış" sayılır.
- **Sadece Telefon**: Bakış ekrandan dışarı çıkarsa ve bu durum ≥10 sn sürerse uyar.
- **Sadece Kitap**: Kullanıcı başını kitaptan kaldırırsa ve bu durum ≥10 sn sürerse uyar. (Not: İlk sürümde kafa eğimi için iOS tarafında `headEulerAngles.pitch` verisi expose edilecek — bkz. design.md TODO.)
- **Hibrit**: Ekrana veya kitaba bakış kabul; ikisi de değilse ≥10 sn'yi aşarsa uyar.

## 🧱 Mimari Özeti
```
lib/
├── main.dart                     # Uygulama girişi ve routing
├── gaze/                         # Gaze core (mevcut)
│   ├── gaze_channel.dart         # iOS bridge (MethodChannel "gaze")
│   ├── gaze_models.dart          # GazeFrame, vb.
│   └── gaze_filter.dart          # 1-Euro filter
├── calibration/                  # 5–9 nokta kalibrasyon
│   ├── calibration_service.dart
│   └── calibration_screen.dart
├── overlay/
│   └── gaze_overlay.dart         # Kamera/overlay alanı
├── auth/                         # (Eklenecek) Login/Signup UI + Firebase bağlama
├── study/                        # (Eklenecek) Mod seçimi + çalışma ekranı + mantık
├── reports/                      # (Eklenecek) Firestore okuma + grafikler
└── logs/
    └── session_logger.dart       # JSONL opsiyonel loglama
```

## ⚙️ Kurulum

### 1) Flutter paketleri
```bash
flutter pub get
```

### 2) iOS gereksinimleri
- iPhone X veya üzeri (TrueDepth)
- Xcode kurulumu ve signing (Automatically manage signing)
- `NSCameraUsageDescription` Info.plist'te mevcut

### 3) Firebase kurulumu
1. Firebase Console'da proje oluştur.
2. iOS uygulaması ekle (Bundle ID Xcode ile aynı olmalı).
3. `GoogleService-Info.plist` dosyasını `ios/Runner/` içine koy.
4. Xcode'da Runner target → Build Phases → Ensure plist included.
5. Uygulama içinde `Firebase.initializeApp()` çağrısı (lib/main.dart başlatma akışında).

### 4) Çalıştırma
```bash
flutter run
```

## 🧪 Kullanım
1) İlk açılışta e-posta ile kayıt/giriş yap.
2) "Ders Çalış" butonuna bas → Mod seç.
3) Çalışma ekranında kamera solda, metrikler sağda. Dikkat dağılırsa uyarı alırsın.
4) Bitirince oturum verileri Firestore'a kaydedilir. "Raporlarım" ile geçmişi incele.

## 🔐 Gizlilik
- Kamera verisi cihazda işlenir; Firestore'a sadece özet metrikler ve olaylar gönderilir.
- Oturum kimliği ve kullanıcı ID'si (Firebase Auth) ile veri ilişkilendirilir.

## 🗺️ Yol Haritası (kısa)
- M1: Auth + modlar + temel dikkat kuralı + Firestore kayıt + günlük raporlar
- M2: iOS `headEulerAngles` köprüsü, hibrit/kitap modunda daha sağlam mantık
- M3: Gelişmiş raporlar, detaylı grafikler, parametre ayarları

## 🚧 Notlar
- İlk sürüm portrait. Landscape TODO.
- Gerçek cihaz gerekli (simulator TrueDepth desteklemez).

## Lisans
MIT
