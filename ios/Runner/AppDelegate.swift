import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Notifications locales : sans ce délégué, une notification reçue alors
    // que l'app est ouverte n'apparaîtrait pas (iOS la masque par défaut).
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate =
        self as? UNUserNotificationCenterDelegate
    }

    // Vérifications en arrière-plan (séances validées, échéances du soir,
    // nouvelle version d'emploi du temps). iOS n'exécute ces tâches que
    // lorsqu'il le juge opportun : c'est une opportunité, pas une garantie —
    // l'app revérifie donc systématiquement à son ouverture.
    WorkmanagerPlugin.registerTask(withIdentifier: "ox_records_check")
    UIApplication.shared.setMinimumBackgroundFetchInterval(
      TimeInterval(15 * 60)
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
