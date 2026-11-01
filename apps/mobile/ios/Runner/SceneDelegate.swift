import Flutter
import UIKit

/// Keep URL callback forwarding in FlutterSceneDelegate so registered plugins,
/// including FlutterFire Auth, get the scene URL through Flutter's lifecycle
/// delegate exactly once.
class SceneDelegate: FlutterSceneDelegate {}
