import Foundation
import FirebaseCore
import FBSDKCoreKit
import GoogleSignIn

class AppService {
    class func bootstrap(_ app: UIApplication) {
        FirebaseApp.configure()
        FBSDKCoreKit.ApplicationDelegate.shared.application(app)
    }
    
    class func handleOpenGoogleUrl(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}
