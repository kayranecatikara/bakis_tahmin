# Teknik Notlar / Uyarılar (Yeni Vizyon)

- Gerçek cihaz zorunlu (TrueDepth). Simulator desteklemez.
- iOS bakış hesabı: `lookAtPoint` veya eye forward vectors → ray-plane → normalize (x,y). Mevcut implementasyon korunur.
- Kalibrasyon: 5–9 nokta; afine fit; parametreleri kullanıcıya ayarlanabilir bırak.
- 1-Euro filter: mincutoff ve beta ayarlanabilir. Düşük gecikme için tercih edilir.
- Orientation: İlk sürüm portrait. Landscape TODO.

## Dikkat Algoritması
- Frame veri modeli: `GazeFrame { x, y, conf, valid, ts }` + (M2) `headPitch` (radyan)
- Telefon modu: (x,y) in [0..1] ve conf>=0.5 → focused; değilse drifting
- Kitap modu: `headPitch` aşağı eğim (ör. < -0.15 rad) → focused; değilse drifting (M2 gerektirir)
- Hibrit: Telefon OR Kitap focused → focused; aksi drifting
- Uyarı kuralı: drifting toplamı ≥ 10s olduğunda uyarı ve sayaç +1, sonra pencere sıfırlanır
- Debounce: 500ms altındaki transient değişiklikler ignore

## Firebase
- `firebase_core`, `firebase_auth`, `cloud_firestore`
- iOS: `GoogleService-Info.plist` konumu `ios/Runner/`
- Koleksiyonlar:
  - `users/{uid}`
  - `users/{uid}/sessions/{sessionId}`: { startTs, endTs, mode, focusRatio, distractCount, events[] }

## Raporlama
- Günlük bazda sorgu: `where startTs >= dayStart && < dayEnd`
- Grafikler: `fl_chart` ile zaman serisi ve gün karşılaştırma

## Performans
- MethodChannel frame başına tek çağrı; gerekirse throttling
- Flutter tarafında sadece overlay repaint; geniş setState'lerden kaçın

## Güvenlik
- Sadece özet metrikler Firestore'a yazılır. Ham frame verileri gönderilmez.
- Kullanıcı verileri userId altında saklanır.
