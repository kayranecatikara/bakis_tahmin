import Foundation
import ARKit
import Flutter

/// ARKit ile göz takibi yapan ve Flutter'a veri gönderen sınıf
class GazeProvider: NSObject {
    private let channel: FlutterMethodChannel
    private var session: ARSession?
    private var isTracking = false
    
    // Frame throttling
    private var lastFrameTime: TimeInterval = 0
    private let minFrameInterval: TimeInterval = 1.0 / 60.0 // Max 60 FPS
    
    init(controller: FlutterViewController) {
        // MethodChannel oluştur
        channel = FlutterMethodChannel(
            name: "gaze",
            binaryMessenger: controller.binaryMessenger
        )
        
        super.init()
        
        // Method çağrılarını dinle
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            startTracking(result: result)
        case "stop":
            stopTracking(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Tracking Control
    
    private func startTracking(result: @escaping FlutterResult) {
        guard !isTracking else {
            result(FlutterError(code: "ALREADY_TRACKING", message: "Gaze tracking is already active", details: nil))
            return
        }
        
        // ARKit desteğini kontrol et
        guard ARFaceTrackingConfiguration.isSupported else {
            result(FlutterError(code: "NOT_SUPPORTED", message: "Face tracking is not supported on this device", details: nil))
            return
        }
        
        // Session oluştur
        session = ARSession()
        session?.delegate = self
        
        // Configuration oluştur
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false // Performans için kapat
        
        // Session'ı başlat
        session?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        isTracking = true
        result(nil)
    }
    
    private func stopTracking(result: @escaping FlutterResult) {
        guard isTracking else {
            result(FlutterError(code: "NOT_TRACKING", message: "Gaze tracking is not active", details: nil))
            return
        }
        
        session?.pause()
        session = nil
        isTracking = false
        result(nil)
    }
    
    // MARK: - Gaze Calculation
    
    private func calculateGazePoint(from faceAnchor: ARFaceAnchor) -> (x: Float, y: Float, confidence: Float)? {
        // Göz takip noktasını al
        guard let lookAtPoint = faceAnchor.lookAtPoint else {
            // lookAtPoint yoksa, göz transform'larından hesapla
            return calculateGazeFromEyeTransforms(faceAnchor)
        }
        
        // lookAtPoint'i normalize et
        // ARKit'te lookAtPoint, kamera koordinat sisteminde metre cinsinden
        // Bunu ekran koordinatlarına çevirmemiz gerekiyor
        
        // Basit projeksiyon (ilk versiyon)
        // Z ekseni kameraya doğru, X sağa, Y yukarı
        let x = lookAtPoint.x
        let y = lookAtPoint.y
        let z = lookAtPoint.z
        
        // Z negatifse (kameraya bakıyor)
        if z < 0 {
            // Perspektif projeksiyon
            let screenX = -x / z  // Negatif çünkü ekran koordinatları ters
            let screenY = -y / z
            
            // Normalize et [0, 1]
            // Varsayılan FOV ve aspect ratio için basit mapping
            let normalizedX = (screenX + 0.5).clamped(to: 0...1)
            let normalizedY = (screenY + 0.5).clamped(to: 0...1)
            
            // Güven skoru (z mesafesine göre)
            let confidence = max(0, min(1, 1.0 - abs(z) / 2.0))
            
            return (x: normalizedX, y: normalizedY, confidence: confidence)
        }
        
        return nil
    }
    
    private func calculateGazeFromEyeTransforms(_ faceAnchor: ARFaceAnchor) -> (x: Float, y: Float, confidence: Float)? {
        // Sol ve sağ göz transform'larını al
        let leftEye = faceAnchor.leftEyeTransform
        let rightEye = faceAnchor.rightEyeTransform
        
        // Göz pozisyonlarının ortalamasını al
        let leftPos = SIMD3<Float>(leftEye.columns.3.x, leftEye.columns.3.y, leftEye.columns.3.z)
        let rightPos = SIMD3<Float>(rightEye.columns.3.x, rightEye.columns.3.y, rightEye.columns.3.z)
        let eyeCenter = (leftPos + rightPos) / 2
        
        // Göz yönlerini al (forward vector)
        let leftForward = -SIMD3<Float>(leftEye.columns.2.x, leftEye.columns.2.y, leftEye.columns.2.z)
        let rightForward = -SIMD3<Float>(rightEye.columns.2.x, rightEye.columns.2.y, rightEye.columns.2.z)
        let gazeDirection = normalize((leftForward + rightForward) / 2)
        
        // Ekran düzlemi ile kesişimi hesapla
        // Varsayılan ekran mesafesi: 0.3 metre
        let screenDistance: Float = 0.3
        let screenPlaneZ: Float = -screenDistance
        
        // Ray-plane intersection
        if gazeDirection.z < 0 { // Ekrana doğru bakıyor
            let t = (screenPlaneZ - eyeCenter.z) / gazeDirection.z
            let intersectionPoint = eyeCenter + t * gazeDirection
            
            // Ekran koordinatlarına dönüştür
            // Varsayılan ekran boyutu: 0.15m x 0.25m (portrait iPhone)
            let screenWidth: Float = 0.15
            let screenHeight: Float = 0.25
            
            let screenX = (intersectionPoint.x + screenWidth/2) / screenWidth
            let screenY = 1.0 - (intersectionPoint.y + screenHeight/2) / screenHeight // Y'yi ters çevir
            
            // Clamp to [0, 1]
            let normalizedX = screenX.clamped(to: 0...1)
            let normalizedY = screenY.clamped(to: 0...1)
            
            // Güven skoru
            let confidence: Float = 0.8 // Sabit güven skoru (iyileştirilebilir)
            
            return (x: normalizedX, y: normalizedY, confidence: confidence)
        }
        
        return nil
    }
}

// MARK: - ARSessionDelegate

extension GazeProvider: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Frame throttling
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastFrameTime >= minFrameInterval else { return }
        lastFrameTime = currentTime
        
        // Face anchor'ı bul
        guard let faceAnchor = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            // Yüz bulunamadı
            sendInvalidFrame()
            return
        }
        
        // Gaze noktasını hesapla
        if let gazePoint = calculateGazePoint(from: faceAnchor) {
            sendGazeFrame(x: gazePoint.x, y: gazePoint.y, confidence: gazePoint.confidence, valid: true)
        } else {
            sendInvalidFrame()
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("ARSession error: \(error)")
        sendInvalidFrame()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("ARSession interrupted")
        sendInvalidFrame()
    }
    
    // MARK: - Flutter Communication
    
    private func sendGazeFrame(x: Float, y: Float, confidence: Float, valid: Bool) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // milliseconds
        
        let frameData: [String: Any] = [
            "x": Double(x),
            "y": Double(y),
            "confidence": Double(confidence),
            "timestamp": timestamp,
            "valid": valid
        ]
        
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onFrame", arguments: frameData)
        }
    }
    
    private func sendInvalidFrame() {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        
        let frameData: [String: Any] = [
            "x": 0.5,
            "y": 0.5,
            "confidence": 0.0,
            "timestamp": timestamp,
            "valid": false
        ]
        
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onFrame", arguments: frameData)
        }
    }
}

// MARK: - Helper Extensions

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }
} 