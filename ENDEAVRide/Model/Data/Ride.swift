//
//  Ride.swift
//  ENDEAVRide
//
//  Created by eavride on 6/6/21.
//

import Foundation

class Ride: Decodable {
    var rid: String
    var status: String
    var uid: String
    var did: String?
    var user_location: String
    var destination: String
    var create_time: String?
    var start_time: String?
    var finish_time: String?
}

class DriveRecord: Decodable {
    var rid: String
    var uid: String
    var did: String
    var status: String
    var driver_location: String
    var create_time: String
}
