import Foundation
import FirebaseCore
import FBSDKCoreKit
import GoogleSignIn
import Logging

let logger = Logger(label: "FlashcardApp")

class AppService {
    class func bootstrap(_ app: UIApplication) {
        FirebaseApp.configure()
        FBSDKCoreKit.ApplicationDelegate.shared.application(app)
        LoggingSystem.bootstrap { label in
            return ColoredLogHandler(label: label)
        }
        
        logger.info("BaseURL: \(EnvironmentConfig.baseUrl())")
    }
    
    class func handleOpenGoogleUrl(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

