//
//  User.swift
//  ENDEAVRide
//
//  Created by 王凯旋 on 6/6/21.
//

import Foundation

class User: Decodable {
    var uid: String
    var email: String
    
    init(uid: String, email: String) {
        self.uid = uid
        self.email = email
    }
}
