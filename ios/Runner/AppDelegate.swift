import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Build the root Flutter view controller in code so app startup does not
    // depend on storyboard compilation.
    if window == nil {
      let flutterViewController = FlutterViewController()
      let appWindow = UIWindow(frame: UIScreen.main.bounds)
      appWindow.rootViewController = flutterViewController
      appWindow.makeKeyAndVisible()
      window = appWindow
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
