//
//  Ride.swift
//  ENDEAVRide
//
//  Created by 王凯旋 on 6/6/21.
//

import Foundation

class Ride: Decodable {
    var rid: String
    var status: String
    var uid: String
    var did: String?
    var direction: String
    var create_time: String?
    var start_time: String?
    var finish_time: String?
}
