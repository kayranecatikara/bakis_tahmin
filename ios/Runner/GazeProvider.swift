import Foundation
import UIKit
import ARKit
import Flutter
import simd

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
        
        guard ARFaceTrackingConfiguration.isSupported else {
            result(FlutterError(code: "NOT_SUPPORTED", message: "Face tracking is not supported on this device", details: nil))
            return
        }
        
        session = ARSession()
        session?.delegate = self
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        
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
    
    private func gazeUsingLookAtProjection(faceAnchor: ARFaceAnchor, frame: ARFrame) -> (x: Float, y: Float, confidence: Float)? {
        // iOS 14+ lookAtPoint mevcutsa kullan, 3B'den ekrana projekte et
        if #available(iOS 14.0, *) {
            if let lp = faceAnchor.lookAtPoint {
                // lookAtPoint yüz lokal uzayında → dünya → kamera
                let lp4 = simd_float4(lp.x, lp.y, lp.z, 1)
                let worldLP = faceAnchor.transform * lp4
                // projectPoint kamera uzayında worldPoint bekler; ARKit cihaz uzayından projekte eder
                // ARCamera.projectPoint doğrudan dünya noktasını kabul eder ve dahili olarak dönüştürür.
                let viewport = UIScreen.main.bounds.size
                // Portrait varsayıyoruz (ilk sürüm)
                let pixel = frame.camera.projectPoint(simd_float3(worldLP.x, worldLP.y, worldLP.z),
                                                       orientation: .portrait,
                                                       viewportSize: viewport)
                let w = Float(viewport.width)
                let h = Float(viewport.height)
                if w <= 0 || h <= 0 { return nil }
                var nx = Float(pixel.x) / w
                var ny = Float(pixel.y) / h
                // Ön kamera ayna etkisi: X’i çevir
                nx = 1.0 - nx
                // Clamp [0,1]
                nx = max(0, min(1, nx))
                ny = max(0, min(1, ny))
                // Basit güven: yüz anchor'ı mevcutsa orta düzey
                let conf: Float = 0.8
                return (nx, ny, conf)
            }
        }
        return nil
    }
    
    private func calculateGazeFromEyeTransforms(_ faceAnchor: ARFaceAnchor) -> (x: Float, y: Float, confidence: Float)? {
        let leftEye = faceAnchor.leftEyeTransform
        let rightEye = faceAnchor.rightEyeTransform
        
        let leftPos = SIMD3<Float>(leftEye.columns.3.x, leftEye.columns.3.y, leftEye.columns.3.z)
        let rightPos = SIMD3<Float>(rightEye.columns.3.x, rightEye.columns.3.y, rightEye.columns.3.z)
        let eyeCenter = (leftPos + rightPos) / 2
        
        let leftForward = -SIMD3<Float>(leftEye.columns.2.x, leftEye.columns.2.y, leftEye.columns.2.z)
        let rightForward = -SIMD3<Float>(rightEye.columns.2.x, rightEye.columns.2.y, rightEye.columns.2.z)
        let gazeDirection = simd_normalize((leftForward + rightForward) / 2)
        
        let screenDistance: Float = 0.3
        let screenPlaneZ: Float = -screenDistance
        
        if gazeDirection.z < 0 {
            let t = (screenPlaneZ - eyeCenter.z) / gazeDirection.z
            let p = eyeCenter + t * gazeDirection
            let screenWidth: Float = 0.15
            let screenHeight: Float = 0.25
            var nx = (p.x + screenWidth/2) / screenWidth
            var ny = 1.0 - (p.y + screenHeight/2) / screenHeight
            // Ön kamera ayna etkisi: X’i çevir
            nx = 1.0 - nx
            nx = max(0, min(1, nx))
            ny = max(0, min(1, ny))
            let confidence: Float = 0.6
            return (nx, ny, confidence)
        }
        return nil
    }
}

// MARK: - ARSessionDelegate

extension GazeProvider: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Face anchor bul
        guard let faceAnchor = frame.anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            sendInvalidFrame()
            return
        }
        
        // Throttle
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= minFrameInterval else { return }
        lastFrameTime = now
        
        // Öncelik: lookAtPoint + projectPoint
        if let g = gazeUsingLookAtProjection(faceAnchor: faceAnchor, frame: frame) {
            sendGazeFrame(x: g.x, y: g.y, confidence: g.confidence, valid: true)
            return
        }
        
        // Fallback: eye-ray → screen-plane
        if let g2 = calculateGazeFromEyeTransforms(faceAnchor) {
            sendGazeFrame(x: g2.x, y: g2.y, confidence: g2.confidence, valid: true)
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
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
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
 