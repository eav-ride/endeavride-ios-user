//
//  LoginModel.swift
//  ENDEAVRide
//
//  Created by eavride on 6/2/21.
//

import Foundation

protocol LoginModelDelegate: AnyObject {
    func redirectToLoginViewController()
}

class LoginModel {
    
    private let userSessionKey = "userSessionKey"
    weak var delegate: LoginModelDelegate?
    
    func checkUserStatus() {
        if let _ = UserDefaults.standard.string(forKey: userSessionKey) {
            // try to login with stored user value
        } else {
            // redirect to login page
            delegate?.redirectToLoginViewController()
        }
    }
    
    func loginUser(email: String, password: String, errorHandler: ((String)->())?) {
        guard let url = URL(string: Utils.baseURL + "user") else {
            return
        }
        NetworkUtils.postToServer(url: url, path: nil, parameterDirctionary: ["email": email, "hash": password]) { data in
            do {
                let user = try JSONDecoder().decode(User.self, from: data)
                Utils.user = user
                DispatchQueue.main.async {
                    self.delegate?.redirectToLoginViewController()
                }
                UserDefaults.standard.setValue(email, forKey: "userEmail")
                UserDefaults.standard.setValue(password, forKey: "userHash")
            } catch {
                print("login error: user decode error")
            }
        } errorHandler: { error in
            print("login error: \(error)")
            if let errorHandler = errorHandler {
                errorHandler(error)
            }
        }
    }
    
    func registerUser(email: String, password: String, errorHandler: ((String)->())?) {
        guard let url = URL(string: Utils.baseURL + "user/register") else {
            return
        }
        NetworkUtils.postToServer(url: url, path: nil, parameterDirctionary: ["email": email, "hash": password]) { data in
            do {
                let user = try JSONDecoder().decode(User.self, from: data)
                Utils.user = user
                DispatchQueue.main.async {
                    self.delegate?.redirectToLoginViewController()
                }
                UserDefaults.standard.setValue(email, forKey: "userEmail")
                UserDefaults.standard.setValue(password, forKey: "userHash")
            } catch {
                print("register error: user decode error")
            }
        } errorHandler: { error in
            print("register error: \(error)")
            if let errorHandler = errorHandler {
                errorHandler(error)
            }
        }
    }
    
    func logout() {
        Utils.user = nil
        Utils.userId = ""
        delegate?.redirectToLoginViewController()
    }
}
