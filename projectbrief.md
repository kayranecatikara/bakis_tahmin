# Project Brief — FocusGuard Gaze

## Misyon
TrueDepth + ARKit kullanarak iOS cihazlarda kullanıcının ekranda baktığı noktayı düşük gecikmeyle, kalibrasyonla düzeltilmiş şekilde göstermek.

## Kullanıcı / Kapsam
- Kullanıcı: iPhone/iPad (Face ID/TrueDepth) sahipleri.
- Kapsam: **Sadece bakış noktası görselleştirme** (top). Sınıflandırma/etkileşim yok.

## Değer Önerisi
- Hızlı kurulum, düşük gecikme, pratik kalibrasyon.
- İleride dikkat izleme ve UX deneyleri için altyapı.

## Teknik Kısıtlar
- iOS derleme: macOS + Xcode zorunlu. Simulator TrueDepth vermez.
- İlk sürüm sadece portrait.

## Başarı Kriterleri
- Gerçek cihazda akıcı imleç.
- Kalibrasyon sonrası belirgin doğruluk artışı.
- Hatasız çalışma (crash yok), stabil FPS.

## Yol Haritası
- M1: Minimum çalışan ürün.
- M2: Orientation, ayar paneli.
- M3: TestFlight dağıtımı, telemetri/log.
