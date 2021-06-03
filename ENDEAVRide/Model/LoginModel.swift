//
//  LoginModel.swift
//  ENDEAVRide
//
//  Created by 王凯旋 on 6/2/21.
//

import Foundation

protocol LoginModelDelegate: AnyObject {
    func redirectToLoginViewController()
}

class LoginModel {
    
    private let userSessionKey = "userSessionKey"
    weak var delegate: LoginModelDelegate?
    
    func checkUserStatus() {
        if let value = UserDefaults.standard.string(forKey: userSessionKey) {
            // try to login with stored user value
        } else {
            // redirect to login page
            delegate?.redirectToLoginViewController()
        }
    }
}
