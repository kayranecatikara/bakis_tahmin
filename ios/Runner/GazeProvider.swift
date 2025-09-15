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
        channel = FlutterMethodChannel(
            name: "gaze",
            binaryMessenger: controller.binaryMessenger
        )
        
        super.init()
        
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
    
    // MARK: - Orientation helpers
    private func currentInterfaceOrientation() -> UIInterfaceOrientation {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.interfaceOrientation ?? .portrait
    }
    
    private func isFrontCameraMirroredX(for orientation: UIInterfaceOrientation) -> Bool {
        // Ön kamera: portrait ve tüm landscape’lerde yatay eksen ayna etkisi var → X’i tersle
        // Landscape dönüşlerinde mapping farklı olsa da tersleme korunur
        return true
    }
    
    // MARK: - Head pose (Euler)
    private func headEulerAngles(from matrix: simd_float4x4) -> simd_float3 {
        // ZYX konvansiyonu (roll-yaw-pitch). Burada x=pitch (yukarı-aşağı), y=yaw, z=roll döndürür.
        let sy = sqrt(matrix.columns.0.x * matrix.columns.0.x + matrix.columns.1.x * matrix.columns.1.x)
        let singular = sy < 1e-6
        var x: Float, y: Float, z: Float
        if !singular {
            x = atan2(matrix.columns.2.y, matrix.columns.2.z)       // pitch
            y = atan2(-matrix.columns.2.x, sy)                      // yaw
            z = atan2(matrix.columns.1.x, matrix.columns.0.x)       // roll
        } else {
            x = atan2(-matrix.columns.1.z, matrix.columns.1.y)
            y = atan2(-matrix.columns.2.x, sy)
            z = 0
        }
        return simd_float3(x, y, z)
    }
    
    // MARK: - Gaze Calculation
    
    private func gazeUsingLookAtProjection(faceAnchor: ARFaceAnchor, frame: ARFrame) -> (x: Float, y: Float, confidence: Float, headPitch: Float)? {
        if #available(iOS 14.0, *) {
            if let lp = faceAnchor.lookAtPoint {
                let lp4 = simd_float4(lp.x, lp.y, lp.z, 1)
                let worldLP = faceAnchor.transform * lp4
                
                let viewport = UIScreen.main.bounds.size
                let orientation = currentInterfaceOrientation()
                let pixel = frame.camera.projectPoint(simd_float3(worldLP.x, worldLP.y, worldLP.z),
                                                      orientation: orientation,
                                                      viewportSize: viewport)
                let w = Float(viewport.width)
                let h = Float(viewport.height)
                if w <= 0 || h <= 0 { return nil }
                var nx = Float(pixel.x) / w
                var ny = Float(pixel.y) / h
                
                // Ön kamera ayna etkisi → X tersleme (tüm oryantasyonlarda)
                if isFrontCameraMirroredX(for: orientation) {
                    nx = 1.0 - nx
                }
                
                nx = max(0, min(1, nx))
                ny = max(0, min(1, ny))
                let conf: Float = 0.8
                let euler = headEulerAngles(from: faceAnchor.transform)
                return (nx, ny, conf, euler.x) // x = pitch
            }
        }
        return nil
    }
    
    private func calculateGazeFromEyeTransforms(_ faceAnchor: ARFaceAnchor) -> (x: Float, y: Float, confidence: Float, headPitch: Float)? {
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
            
            // Aynalama
            if isFrontCameraMirroredX(for: currentInterfaceOrientation()) {
                nx = 1.0 - nx
            }
            
            nx = max(0, min(1, nx))
            ny = max(0, min(1, ny))
            let confidence: Float = 0.6
            let euler = headEulerAngles(from: faceAnchor.transform)
            return (nx, ny, confidence, euler.x)
        }
        return nil
    }
}

// MARK: - ARSessionDelegate

extension GazeProvider: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let faceAnchor = frame.anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            sendInvalidFrame()
            return
        }
        
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= minFrameInterval else { return }
        lastFrameTime = now
        
        if let g = gazeUsingLookAtProjection(faceAnchor: faceAnchor, frame: frame) {
            sendGazeFrame(x: g.x, y: g.y, confidence: g.confidence, valid: true, headPitch: g.headPitch)
            return
        }
        
        if let g2 = calculateGazeFromEyeTransforms(faceAnchor) {
            sendGazeFrame(x: g2.x, y: g2.y, confidence: g2.confidence, valid: true, headPitch: g2.headPitch)
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
    
    private func sendGazeFrame(x: Float, y: Float, confidence: Float, valid: Bool, headPitch: Float?) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        var frameData: [String: Any] = [
            "x": Double(x),
            "y": Double(y),
            "confidence": Double(confidence),
            "timestamp": timestamp,
            "valid": valid
        ]
        if let hp = headPitch {
            frameData["headPitch"] = Double(hp)
        }
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
 