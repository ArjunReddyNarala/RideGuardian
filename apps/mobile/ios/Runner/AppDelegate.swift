import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // TODO: Add your Google Maps API key
    GMSServices.provideAPIKey("AIzaSyC-tDi3tfeGV2XDhBNB_VRebBMhzgTNuG8")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let batteryChannel = FlutterMethodChannel(
      name: "rideguardian/device_battery",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    batteryChannel.setMethodCallHandler { call, result in
      guard call.method == "getBatteryLevel" else {
        result(FlutterMethodNotImplemented)
        return
      }

      UIDevice.current.isBatteryMonitoringEnabled = true
      let batteryLevel = UIDevice.current.batteryLevel
      result(batteryLevel < 0 ? nil : Int(batteryLevel * 100))
    }
  }
}
