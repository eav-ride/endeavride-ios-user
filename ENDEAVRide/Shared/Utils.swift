//
//  Utils.swift
//  ENDEAVRide
//
//  Created by eavride on 6/6/21.
//

import Foundation
import GooglePlaces

class Utils {
    static var baseURL = "http://192.168.1.75:3300/"
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
