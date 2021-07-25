//
//  Utils.swift
//  ENDEAVRide
//
//  Created by eavride on 6/6/21.
//

import Foundation
import GooglePlaces

class Utils {
    static var baseURL = "http://ec2-18-220-53-8.us-east-2.compute.amazonaws.com:3300/"  //aws ec2 server
//    static var baseURL = "http://192.168.1.75:3300/"  //local server, change to your local server IP address
    static var userId = ""
    static var user: User? {
        didSet{
            if let id = user?.uid {
                Utils.userId = id
            }
        }
    }
    static var mapsKey = "AIzaSyBQLhQPNU5UFQczahI4ZHX4CReuH1D5o8U"
    
    static func decodeLocationString(location: String) -> CLLocationCoordinate2D? {
        let point = location.split(separator: ",")
        if (point.count != 2) {return nil}
        guard let lat = CLLocationDegrees(point[0]), let lon = CLLocationDegrees(point[1]) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    static func encodeLocationString(location: CLLocationCoordinate2D) -> String {
        return "\(location.latitude),\(location.longitude)"
    }
}

class Toast {
    static func show(message: String, controller: UIViewController) {
        let toastContainer = UIView(frame: CGRect())
        toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastContainer.alpha = 0.0
        toastContainer.layer.cornerRadius = 15;
        toastContainer.clipsToBounds  =  true

        let toastLabel = UILabel(frame: CGRect())
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font.withSize(12.0)
        toastLabel.text = message
        toastLabel.clipsToBounds  =  true
        toastLabel.numberOfLines = 0

        toastContainer.addSubview(toastLabel)
        controller.view.addSubview(toastContainer)

        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let constraints = [
            toastLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: 15),
            toastLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -15),
            toastLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: 5),
            toastLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -5),
            
            toastContainer.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            toastContainer.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor, constant: -75)
        ]
        
        NSLayoutConstraint.activate(constraints)

        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseIn, animations: {
            toastContainer.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 1.5, options: .curveEaseOut, animations: {
                toastContainer.alpha = 0.0
            }, completion: {_ in
                toastContainer.removeFromSuperview()
            })
        })
    }
}
