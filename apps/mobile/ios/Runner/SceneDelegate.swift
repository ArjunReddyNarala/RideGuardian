import Flutter
import UIKit
import FirebaseAuth

class SceneDelegate: FlutterSceneDelegate {

    override func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        print("RideGuardian: SceneDelegate received URL callback")

        for urlContext in URLContexts {
            let url = urlContext.url
            let handled = Auth.auth().canHandle(url)

            print("RideGuardian: Firebase handled callback = \(handled)")

            if handled {
                return
            }
        }

        super.scene(scene, openURLContexts: URLContexts)
    }
}
