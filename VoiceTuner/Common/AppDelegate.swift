//
//  AppDelegate.swift
//  VoiceTuner
//
//  Created by Max on 31.07.21.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    window = UIWindow(frame: UIScreen.main.bounds)
    let mainVC = MainViewController()
    let navMain = UINavigationController(rootViewController: mainVC)
    window?.rootViewController = navMain
    window?.makeKeyAndVisible()
    return true
  }
}

