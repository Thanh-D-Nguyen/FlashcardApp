//
//  SocialUserEntity.swift
//  SnackOverflowApp
//
//  Created by タイン・グエン on 2023/02/05.
//

import Foundation

struct SocialUserEntity: Codable {
    var id: String? = nil
    var displayName: String?
    var email: String?
    var phoneNumber: String?
    var photoUrl: URL?

    init(id: String? = nil, displayName: String? = nil, email: String? = nil, phoneNumber: String? = nil, photoUrl: URL? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.phoneNumber = phoneNumber
        self.photoUrl = photoUrl
    }
}
