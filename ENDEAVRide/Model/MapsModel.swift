//
//  MapsModel.swift
//  ENDEAVRide
//
//  Created by eavride on 6/6/21.
//

import Foundation
import GooglePlaces

protocol MapsModelDelegate: AnyObject {
    func createRideOnComplete(ride: Ride?)
    func updateDirectionPolyline(path: Array<String>)
    func updateDriverRecord(record: DriveRecord?)
}

class MapsModel {
    weak var delegate: MapsModelDelegate?
    private var rid: String?
    
    func createRide(type: Int, origin: CLLocation?, destination: CLLocationCoordinate2D) {
        guard let url = URL(string: Utils.baseURL + "r") else {
            return
        }
        var params: [String: Any] = [
            "destination": Utils.encodeLocationString(location: destination),
            "type": type,
            "uid": Utils.userId]
        if let origin = origin {
            params["user_location"] = Utils.encodeLocationString(location: origin.coordinate)
        }
        NetworkUtils.postToServer(url: url, path: nil, parameterDirctionary: params) { data in
            do {
                let ride = try JSONDecoder().decode(Ride.self, from: data)
                self.rid = ride.rid
                DispatchQueue.main.async {
                    self.delegate?.createRideOnComplete(ride: ride)
                }
            } catch {
                print("create ride error: ride decode error, \(error)")
            }
        } errorHandler: { error in
            print("create ride error: \(error)")
        }
    }
    
    func cancelRide() {
        guard let rid = rid, let url = URL(string: Utils.baseURL + "r/\(rid)") else {
            return
        }
        let params: [String: Any] = [
            "status": OrderStatus.cancelled.rawValue]
        NetworkUtils.postToServer(url: url, path: nil, parameterDirctionary: params) { data in
            do {
                let ride = try JSONDecoder().decode(Ride.self, from: data)
                self.rid = nil
                DispatchQueue.main.async {
                    self.delegate?.createRideOnComplete(ride: ride)
                }
            } catch {
                print("cancel ride error: ride decode error, \(error)")
            }
        } errorHandler: { error in
            print("cancel ride error: \(error)")
        }
    }
    
    func checkIfCurrentRideAvailable() {
        guard let url = URL(string: Utils.baseURL + "r") else {
            return
        }
        NetworkUtils.getFromServer(url: url, header: nil, queryItem: nil) { data in
            do {
                let ride = try JSONDecoder().decode(Ride.self, from: data)
                self.rid = ride.rid
                DispatchQueue.main.async {
                    self.delegate?.createRideOnComplete(ride: ride)
                }
            } catch {
                print("request current ride error: ride decode error, \(error)")
                DispatchQueue.main.async {
                    self.delegate?.createRideOnComplete(ride: nil)
                }
            }
        } errorHandler: { error in
            print("request current ride error: \(error)")
            DispatchQueue.main.async {
                self.delegate?.createRideOnComplete(ride: nil)
            }
        }
    }
    
    func refreshRide(delay: UInt32 = 0, showFinish: Bool = false) {
        guard let rid = rid, let url = URL(string: Utils.baseURL + "r/\(rid)") else {
            return
        }
        DispatchQueue.global().async {
            sleep(delay)
            NetworkUtils.getFromServer(url: url, header: nil, queryItem: [
                URLQueryItem(name: "showfinish", value: showFinish.description)
            ]) { data in
                do {
                    let ride = try JSONDecoder().decode(Ride.self, from: data)
                    DispatchQueue.main.async {
                        self.delegate?.createRideOnComplete(ride: ride)
                    }
                } catch {
                    print("request current ride error: ride decode error, \(error)")
                }
            } errorHandler: { error in
                print("request current ride error: \(error)")
            }
        }
    }
    
    func pollDriveRecord() {
        guard let rid = rid, let url = URL(string: Utils.baseURL + "dr/\(rid)") else {
            return
        }
        DispatchQueue.global().async {
            NetworkUtils.getFromServer(url: url, header: nil, queryItem: nil) { data in
                do {
                    sleep(3)
                    let record = try JSONDecoder().decode(DriveRecord.self, from: data)
                    DispatchQueue.main.async {
                        self.delegate?.updateDriverRecord(record: record)
                    }
                } catch {
                    print("request driver record error: record decode error, \(error)")
                    DispatchQueue.main.async {
                        self.delegate?.updateDriverRecord(record: nil)
                    }
                }
            } errorHandler: { error in
                print("request driver record error: \(error)")
                DispatchQueue.main.async {
                    self.delegate?.updateDriverRecord(record: nil)
                }
            }
        }
    }
    
    //MARK: Google maps direction API
    func requestDirection(origin: CLLocationCoordinate2D, dest: CLLocationCoordinate2D) {
        guard let url = URL(string: "https://maps.googleapis.com/maps/api/directions/json") else {
            return
        }
        NetworkUtils.getFromServer(url: url, header: nil, queryItem: [
            URLQueryItem(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
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
            print("request ride direction error: \(error)")
        }

    }
}
