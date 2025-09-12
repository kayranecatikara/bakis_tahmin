# Project Brief — FocusGuard Study

## Misyon
Öğrencilerin ders çalışırken dikkatlerini korumalarına yardımcı olmak: bakış tahmini ile dikkat dışına çıktıklarında uyarmak ve çalışma geçmişlerini anlamlı raporlarla sunmak.

## Kapsam
- iOS (TrueDepth + ARKit) ile bakış tahmini — mevcut çekirdek korunur
- Flutter arayüz: Auth, mod seçimi, çalışma ekranı, raporlar
- Firebase: Auth (e-posta/şifre) ve Firestore (oturum verileri)

## Kullanıcı Değeri
- Dikkat dağıldığında 10s kuralı ile anında uyarı
- Günlük çalışma süreleri ve odaklanma metrikleri
- Gün karşılaştırma ve grafiklerle ilerlemenin görünür kılınması

## Başarı Kriterleri (M1)
- Giriş/Kayıt akışı çalışıyor
- 3 mod için temel dikkat kuralı (≥10s uyarı) işliyor
- Oturum verileri Firestore'a yazılıyor ve Raporlarım ekranında gün bazlı görüntüleniyor

## Teknik Kısıtlar
- Gerçek cihaz (TrueDepth) zorunlu, simulator desteklemez
- İlk sürüm portrait
- Bağımlılıklar minimal: Firebase çekirdeği, grafikler için tek kütüphane

## Yol Haritası
- M1: Auth + modlar + temel dikkat mantığı + Firestore + günlük raporlar
- M2: iOS kafa eğimi (`headPitch`) köprüsü ve mod doğruluğu artışı
- M3: Gelişmiş raporlar, parametrik ayarlar, iyileştirilmiş UX
