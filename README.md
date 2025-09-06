# FocusGuard Gaze - iOS Bakış Takibi Uygulaması

Flutter + iOS ARKit/TrueDepth kullanarak gerçek zamanlı bakış noktası tahmini yapan uygulama.

## 🎯 Özellikler

- **Gerçek Zamanlı Bakış Takibi**: iOS TrueDepth kamera ile 60 FPS'e kadar takip
- **1-Euro Filtresi**: Stabil ve düşük gecikmeli imleç hareketi
- **9 Noktalı Kalibrasyon**: Afine dönüşüm ile hassas kalibrasyon
- **JSON Loglama**: Analiz için detaylı session kayıtları
- **Canlı Overlay**: Bakış noktasını gösteren görsel işaretçi

## 📱 Gereksinimler

- **Cihaz**: iPhone X veya üzeri (TrueDepth kamera gerekli)
- **iOS**: 11.0 veya üzeri
- **macOS**: Xcode 14+ (derleme için)
- **Flutter**: 3.0 veya üzeri

## 🚀 Hızlı Başlangıç

### 1. Projeyi Klonlayın
```bash
git clone <repo-url>
cd bakis_tahmin
```

### 2. Flutter Bağımlılıklarını Yükleyin
```bash
flutter pub get
```

### 3. iOS Pod'ları Yükleyin
```bash
cd ios
pod install
cd ..
```

### 4. Xcode'da Signing Ayarları

1. `ios/Runner.xcworkspace` dosyasını Xcode'da açın
2. Sol panelde "Runner" projesini seçin
3. "Signing & Capabilities" sekmesine gidin
4. "Team" dropdown'ından Apple Developer hesabınızı seçin
5. "Bundle Identifier"ı benzersiz yapın (örn: `com.yourname.focusguardgaze`)
6. "Automatically manage signing" kutusunu işaretleyin

### 5. Cihaza Yükleme ve Çalıştırma

**Yöntem 1: Flutter CLI**
```bash
# Bağlı cihazları listele
flutter devices

# Uygulamayı çalıştır
flutter run
```

**Yöntem 2: Xcode**
1. Xcode'da scheme'i "Runner" olarak ayarlayın
2. Target device olarak iPhone'unuzu seçin
3. ▶️ (Run) butonuna tıklayın

## 📋 Kullanım

### Ana Ekran Kontrolleri

- **Takibi Başlat/Durdur**: Gaze takibini aktif/pasif yapar
- **Kalibrasyon Başlat**: 9 noktalı kalibrasyon sihirbazını açar
- **Overlay Toggle**: Bakış noktası görselini açar/kapar
- **Loglama Toggle**: JSON loglama özelliğini aktif eder

### Kalibrasyon Süreci

1. "Kalibrasyon Başlat" butonuna tıklayın
2. Ekranda beliren kırmızı noktalara sırayla bakın
3. Her nokta için 30 frame toplanır (yaklaşık 0.5 saniye)
4. 9 nokta tamamlandığında kalibrasyon otomatik kaydedilir

### Filtre Ayarları

- **Min Cutoff** (0.1-5.0): Düşük değerler daha stabil, yüksek değerler daha hızlı tepki
- **Beta** (0.0-2.0): Hız hassasiyeti, yüksek değerler hızlı hareketlerde daha az gecikme

## 🏗️ Mimari

```
lib/
├── main.dart                    # Ana uygulama ve UI
├── gaze/
│   ├── gaze_channel.dart       # iOS ile MethodChannel iletişimi
│   ├── gaze_models.dart        # Veri modelleri
│   └── gaze_filter.dart        # 1-Euro filtre implementasyonu
├── overlay/
│   └── gaze_overlay.dart       # Bakış noktası görsel widget'ı
├── calibration/
│   ├── calibration_service.dart # Afine dönüşüm hesaplamaları
│   └── calibration_screen.dart  # Kalibrasyon UI
└── logs/
    └── session_logger.dart      # JSON loglama

ios/Runner/
├── AppDelegate.swift            # iOS uygulama başlangıcı
├── GazeProvider.swift          # ARKit göz takibi implementasyonu
└── Info.plist                  # Kamera izni tanımı
```

## 📊 Veri Formatı

### GazeFrame
```json
{
  "x": 0.512,        // Normalize X [0..1], sol-üst (0,0)
  "y": 0.387,        // Normalize Y [0..1]
  "confidence": 0.92, // Güven skoru [0..1]
  "timestamp": 1234567890, // Milliseconds
  "valid": true      // Frame geçerliliği
}
```

### Log Dosyaları
- Konum: `Documents/gaze_logs/`
- Format: JSONL (her satır bir JSON object)
- İçerik: Session bilgisi, frame verileri, eventler

## 🔧 Sorun Giderme

### "Face tracking is not supported"
- Cihazınızda TrueDepth kamera olduğundan emin olun
- iOS 11.0+ yüklü olmalı

### Takip başlamıyor
- Kamera iznini kontrol edin (Ayarlar > Gizlilik > Kamera)
- Yeterli ışık olduğundan emin olun
- Yüzünüz kameraya 25-60cm mesafede olmalı

### Kalibrasyon hatalı
- Kalibrasyon sırasında başınızı sabit tutun
- Her noktaya tam olarak bakın
- Gerekirse kalibrasyonu tekrarlayın

## 🚧 Gelecek İyileştirmeler (TODO)

- [ ] Landscape orientation desteği
- [ ] Daha gelişmiş kalibrasyon algoritması (2. derece polinom)
- [ ] Adaptif filtre parametreleri
- [ ] Göz kırpma algılama
- [ ] Dwell-based tıklama
- [ ] Android desteği (ARCore ile)

## 📝 Notlar

- İlk sürüm sadece portrait modda çalışır
- Simulator'da çalışmaz (TrueDepth gerekli)
- Optimum mesafe: 30-50cm
- Gözlük takılabilir, ancak doğruluk etkilenebilir

## 📄 Lisans

MIT

## 🤝 Katkıda Bulunma

Pull request'ler kabul edilir. Büyük değişiklikler için önce issue açınız.

---

## Mac'te Çalıştırma Kontrol Listesi

### ✅ Ön Hazırlık
- [ ] Xcode yüklü (App Store'dan)
- [ ] Flutter yüklü (`flutter doctor` ile kontrol)
- [ ] CocoaPods yüklü (`sudo gem install cocoapods`)
- [ ] iPhone bağlı ve güvenilir (Trust This Computer)

### ✅ Proje Kurulumu
```bash
# 1. Proje dizinine git
cd /path/to/bakis_tahmin

# 2. Flutter paketlerini yükle
flutter pub get

# 3. iOS bağımlılıklarını yükle
cd ios && pod install && cd ..

# 4. Xcode'u aç
open ios/Runner.xcworkspace
```

### ✅ Xcode Ayarları
1. **Signing**: Team seçin, Bundle ID'yi değiştirin
2. **Device**: iPhone'unuzu seçin (simulator değil!)
3. **Build**: Cmd+B ile derleyin
4. **Run**: Cmd+R ile çalıştırın

### ✅ İlk Çalıştırma
1. Kamera izni isteğini onaylayın
2. "Takibi Başlat" butonuna tıklayın
3. Kırmızı noktanın bakışınızı takip ettiğini görün
4. Kalibrasyon yaparak doğruluğu artırın

### ✅ Sorun Durumunda
```bash
# Flutter clean
flutter clean
flutter pub get

# iOS clean
cd ios
pod deintegrate
pod install
cd ..

# Xcode'da: Product > Clean Build Folder (Shift+Cmd+K)
```
