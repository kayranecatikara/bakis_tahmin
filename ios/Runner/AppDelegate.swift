import Flutter
import UIKit
import ARKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var gazeProvider: GazeProvider?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Flutter root view controller'ı al
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        // GazeProvider'ı başlat
        gazeProvider = GazeProvider(controller: controller)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
