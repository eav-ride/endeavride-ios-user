//
//  LoginViewController.swift
//  ENDEAVRide
//
//  Created by 王凯旋 on 6/2/21.
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
        // Do any additional setup after loading the view.
        
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
        loginModel.loginUser(email: email, password: password)
    }
    
    @IBAction func onRegisterButtonClicked(_ sender: Any) {
        guard let email = emailTextfield.text, let password = passwordTextfield.text else {
            return
        }
        loginModel.registerUser(email: email, password: password)
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension LoginViewController: LoginModelDelegate {
    func redirectToLoginViewController() {
        if let onCompleteBlock = onCompleteBlock {
            onCompleteBlock()
        }
        self.dismiss(animated: true, completion: nil)
    }
}
