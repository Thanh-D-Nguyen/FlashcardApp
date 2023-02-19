//
//  SocialUserEntity.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/02/05.
//

import Foundation
import FirebaseAuth

struct SocialUserEntity: Codable {
    var displayName: String?
    var email: String?
    var phoneNumber: String?
    var photoUrl: URL?
    
    init(_ user: User?) {
        displayName = user?.displayName
        email = user?.email
        phoneNumber = user?.phoneNumber
        photoUrl = user?.photoURL
    }
}
