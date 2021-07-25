//
//  LoginViewController.swift
//  ENDEAVRide
//
//  Created by eavride on 6/2/21.
//

import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var emailTextfield: UITextField!
    @IBOutlet weak var passwordTextfield: UITextField!
    
    private var loginModel: LoginModel!
    var onCompleteBlock: (()->())?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        loginModel = LoginModel()
        loginModel.delegate = self
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))

       view.addGestureRecognizer(tap)
        
        if let username = UserDefaults.standard.string(forKey: "userEmail") {
            emailTextfield.text = username
        }
        if let password = UserDefaults.standard.string(forKey: "userHash") {
            passwordTextfield.text = password
        }
    }

    @IBAction func onLoginButtonClicked(_ sender: Any) {
        guard let email = emailTextfield.text, let password = passwordTextfield.text else {
            return
        }
        loginModel.loginUser(email: email, password: password) { error in
            Toast.show(message: "Login error: \(error)", controller: self)
        }
    }
    
    @IBAction func onRegisterButtonClicked(_ sender: Any) {
        guard let email = emailTextfield.text, let password = passwordTextfield.text else {
            return
        }
        loginModel.registerUser(email: email, password: password) { error in
            Toast.show(message: "Register error: \(error)", controller: self)
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

extension LoginViewController: LoginModelDelegate {
    func redirectToLoginViewController() {
        if let onCompleteBlock = onCompleteBlock {
            onCompleteBlock()
        }
        self.dismiss(animated: true, completion: nil)
    }
}
