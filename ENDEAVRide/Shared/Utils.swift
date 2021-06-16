//
//  Utils.swift
//  ENDEAVRide
//
//  Created by 王凯旋 on 6/6/21.
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
    static var mapsKey = "AIzaSyAxxnazPy8mIAROs-chSCrDknDvzyB3Vho"
    
    static func decodeRideDirection(direction: String) -> CLLocationCoordinate2D? {
        let dir = direction.split(separator: ";")
        if (dir.count != 2) {return nil}
        let point = dir[1].split(separator: ",")
        if (point.count != 2) {return nil}
        guard let lat = CLLocationDegrees(point[0]), let lon = CLLocationDegrees(point[1]) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
