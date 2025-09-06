# TODO - FocusGuard Gaze

## ✅ Tamamlananlar (M1)

- [x] Flutter proje iskeleti oluştur
- [x] iOS native ARKit entegrasyonu (GazeProvider.swift)
- [x] MethodChannel bağlantısı ("gaze" channel)
- [x] 1-Euro filtresi implementasyonu
- [x] Kalibrasyon sistemi (9 noktalı, afine dönüşüm)
- [x] Gaze overlay widget'ı (kırmızı top)
- [x] Session logger (JSONL format)
- [x] README ve kurulum dokümanı
- [x] Info.plist kamera izni (NSCameraUsageDescription)
- [x] Temel UI kontrolleri (Start/Stop, Kalibrasyon, Overlay toggle)

## 🚧 Devam Eden

- [ ] Mac'te gerçek cihazda test
- [ ] Kalibrasyon parametrelerini fine-tune et
- [ ] FPS optimizasyonu

## 📋 Yapılacaklar (M2)

### Yakın Dönem
- [ ] Landscape orientation desteği
- [ ] Daha gelişmiş kalibrasyon algoritması (2. derece polinom)
- [ ] Adaptif filtre parametreleri (hareket hızına göre)
- [ ] Kalibrasyon doğruluk metrikleri gösterimi
- [ ] Log dosyalarını görüntüleme/export ekranı
- [ ] Ayarlar ekranı (filtre parametreleri, kalibrasyon ayarları)

### Orta Dönem
- [ ] Göz kırpma algılama ve filtreleme
- [ ] Head pose compensation
- [ ] Multi-user profil desteği (farklı kalibrasyonlar)
- [ ] Kalibrasyon otomatik iyileştirme (online learning)
- [ ] TestFlight beta dağıtımı

### Uzun Dönem (M3+)
- [ ] Dwell-based tıklama/seçim
- [ ] Gesture tanıma (göz hareketleri)
- [ ] Android desteği (ARCore ile)
- [ ] Accessibility entegrasyonu (iOS Switch Control)
- [ ] Analytics ve telemetri
- [ ] Cloud sync (kalibrasyon verileri)

## 🐛 Bilinen Sorunlar

- [ ] Simulator'da çalışmıyor (TrueDepth gerekli)
- [ ] Düşük ışıkta doğruluk azalıyor
- [ ] Gözlüklü kullanıcılarda kalibrasyon hassasiyeti
- [ ] İlk frame'de gecikme olabiliyor

## 💡 İyileştirme Önerileri

- [ ] Kalibrasyon sırasında görsel geri bildirim ekle
- [ ] Kalibrasyon kalitesi skoru göster
- [ ] Otomatik kalibrasyon hatırlatıcısı
- [ ] Debug overlay modu (raw vs filtered değerler)
- [ ] Performans profiling ve optimizasyon

## 📝 Notlar

- ARKit'in `lookAtPoint` API'si iOS 14+'da mevcut, fallback olarak eye transforms kullanılıyor
- 1-Euro filtresi parametreleri kullanıcı bazlı ayarlanabilir olmalı
- Kalibrasyon verileri cihaz rotasyonuna duyarlı (şimdilik sadece portrait)
- Log dosyaları büyüyebilir, otomatik temizleme mekanizması eklenebilir

## 🔬 Test Edilecekler

- [ ] Farklı iPhone modellerinde test (X, 11, 12, 13, 14, 15 serisi)
- [ ] Farklı ışık koşullarında test
- [ ] Farklı mesafelerde test (25cm - 60cm arası)
- [ ] Gözlüklü/gözlüksüz karşılaştırma
- [ ] Uzun süreli kullanım testi (drift kontrolü)
- [ ] Batarya tüketimi analizi

## 📚 Araştırma

- [ ] Apple'ın Vision framework'ü entegrasyonu
- [ ] Core ML modeli ile göz takibi iyileştirme
- [ ] Pupil Labs referans implementasyonu inceleme
- [ ] Tobii eye tracking SDK karşılaştırması
