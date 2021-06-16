//
//  MapsModel.swift
//  ENDEAVRide
//
//  Created by 王凯旋 on 6/6/21.
//

import Foundation
import GooglePlaces

protocol MapsModelDelegate: AnyObject {
    func createRideOnComplete(ride: Ride)
    func updateDirectionPolyline(path: Array<String>)
}

class MapsModel {
    weak var delegate: MapsModelDelegate?
    
    func createRide(origin: CLLocation, dest: CLLocationCoordinate2D) {
        guard let url = URL(string: Utils.baseURL + "r") else {
            return
        }
        let direction = "\(origin.coordinate.latitude),\(origin.coordinate.longitude);\(dest.latitude),\(dest.longitude)"
        NetworkUtils.postToServer(url: url, path: nil, parameterDirctionary: ["direction": direction, "uid": Utils.userId]) { data in
            do {
                let ride = try JSONDecoder().decode(Ride.self, from: data)
                DispatchQueue.main.async {
                    self.delegate?.createRideOnComplete(ride: ride)
                }
            } catch {
                print("#K_create ride error: ride decode error, \(error)")
            }
        } errorHandler: { error in
            print("#K_create ride error: \(error)")
        }
    }
    
    func checkIfCurrentRideAvailable() {
        guard let url = URL(string: Utils.baseURL + "r") else {
            return
        }
        NetworkUtils.getFromServer(url: url, header: nil, queryItem: nil) { data in
            do {
                let ride = try JSONDecoder().decode(Ride.self, from: data)
                DispatchQueue.main.async {
                    self.delegate?.createRideOnComplete(ride: ride)
                }
            } catch {
                print("#K_request current ride error: ride decode error, \(error)")
            }
        } errorHandler: { error in
            print("#K_request current ride error: \(error)")
        }

    }
    
    func requestDirection(origin: CLLocation, dest: CLLocationCoordinate2D) {
        guard let url = URL(string: "https://maps.googleapis.com/maps/api/directions/json") else {
            return
        }
        NetworkUtils.getFromServer(url: url, header: nil, queryItem: [
            URLQueryItem(name: "origin", value: "\(origin.coordinate.latitude),\(origin.coordinate.longitude)"),
            URLQueryItem(name: "destination", value: "\(dest.latitude),\(dest.longitude)"),
            URLQueryItem(name: "key", value: Utils.mapsKey)
        ]) { data in
            var path = Array<String>()
            guard let dictionary = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? Dictionary<String, AnyObject> else {
                return
            }
            let selectedRoute = (dictionary["routes"] as? Array<Dictionary<String, AnyObject>>)?[0]
            guard let legs = (selectedRoute?["legs"] as? Array<Dictionary<String, AnyObject>>)?[0],
                  let steps = legs["steps"] as? Array<Dictionary<String, AnyObject>> else {
                return
            }
            for step in steps {
                guard let points = (step["polyline"] as? [String: Any])?["points"] as? String else {
                    return
                }
                path.append(points)
            }
            self.delegate?.updateDirectionPolyline(path: path)
        } errorHandler: { error in
            print("#K_request ride direction error: \(error)")
        }

    }
}
