//
//  MapsViewController.swift
//  ENDEAVRide
//
//  Created by eavride on 6/1/21.
//

import UIKit
import GoogleMaps
import GooglePlaces

enum OrderStatus: Int {
    case defaultStatus = -1, unassigned = 0, assigning = 1, picking = 2, arrivedAtUserLocation = 3, started = 4, finished = 5, cancelled = 6
}
enum OrderType: Int {
    case ride = 0, home = 1
}

class MapsViewController: UIViewController {

    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var buttonContainerView: UIStackView!
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    
    private var mapView: GMSMapView!
    private var locationManager: CLLocationManager!
    private var currentLocation: CLLocation?
    private var driverLocation: CLLocationCoordinate2D? {
        didSet {
            if let driverLocation = driverLocation {
                if let _ = driverMarker {
                    driverMarker?.position = driverLocation
                } else {
                    let marker = GMSMarker(position: driverLocation)
                    marker.title = "Driver"
                    marker.map = mapView
                    driverMarker = marker
                }
            }
        }
    }
    private var driverMarker: GMSMarker?
    private var placesClient: GMSPlacesClient!
    private var preciseLocationZoomLevel: Float = 15.0
    private var approximateLocationZoomLevel: Float = 10.0
    private var type: OrderType = .ride
    private var status: OrderStatus = .defaultStatus {
        didSet {
            reloadData()
        }
    }
    
    // An array to hold the list of likely places.
    private var likelyPlaces: [GMSPlace] = []

    // The currently selected place.
    var selectedPlace: GMSPlace?
    private var destination: CLLocationCoordinate2D?
    private var userLocation: CLLocationCoordinate2D?
    private var isPollingDriveRecord = false
    
    private var model: MapsModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let loginModel = LoginModel.init()
        loginModel.delegate = self
        loginModel.checkUserStatus()
        
        model = MapsModel()
        model.delegate = self
        
        clearButton.layer.cornerRadius = 10
        actionButton.layer.cornerRadius = 10
        
        // Initialize the location manager.
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.distanceFilter = 50
        locationManager.startUpdatingLocation()
        locationManager.delegate = self
        
        placesClient = GMSPlacesClient.shared()
        
        let defaultLocation = CLLocation(latitude: -33.869405, longitude: 151.199)

        // Create a map.
        let zoomLevel = locationManager.accuracyAuthorization == .fullAccuracy ? preciseLocationZoomLevel : approximateLocationZoomLevel
        let camera = GMSCameraPosition.camera(withLatitude: defaultLocation.coordinate.latitude,
                                              longitude: defaultLocation.coordinate.longitude,
                                              zoom: zoomLevel)
        mapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
        mapView.settings.myLocationButton = true
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.isMyLocationEnabled = true
        mapView.delegate = self
        self.view.addSubview(mapView)
        self.view.bringSubviewToFront(buttonContainerView)
        
        listLikelyPlaces()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard mapView != nil, Utils.userId != "" else {
            return
        }
        model.checkIfCurrentRideAvailable()
    }
    
    private func reloadData() {
        switch status {
        case .unassigned, .assigning:
            actionButton.setTitle("Waiting available drivers...", for: .normal)
            actionButton.isEnabled = false
            clearButton.setTitle("Cancel", for: .normal)
            clearButton.isEnabled = true
            clearButton.isHidden = false
            
            model.refreshRide(delay: 3)
        case .picking:
            print("#K_ driver picking user")
            actionButton.setTitle("Ride received, waiting for pick up...", for: .normal)
            actionButton.isEnabled = false
            clearButton.isHidden = true
            buttonContainerView.removeArrangedSubview(clearButton)
            
            if (!isPollingDriveRecord) {
                isPollingDriveRecord = true
                print("#K_ start polling driver record")
                model.pollDriveRecord()
            }
            model.refreshRide(delay: 5)
        case.arrivedAtUserLocation:
            print("#K_ driver arrived at user's place")
            actionButton.setTitle("Driver arrived!", for: .normal)
            actionButton.isEnabled = false
            clearButton.isHidden = true
            buttonContainerView.removeArrangedSubview(clearButton)
            
            isPollingDriveRecord = false
            model.refreshRide(delay: 5)
        case .started:
            print("#K_ user abord")
            actionButton.setTitle(type == .ride ? "Sit tight, heading to your destination!" : "Driver is on the way!", for: .normal)
            actionButton.isEnabled = false
            clearButton.isHidden = true
            buttonContainerView.removeArrangedSubview(clearButton)
            
            if (!isPollingDriveRecord) {
                isPollingDriveRecord = true
                print("#K_ start polling driver record")
                locationManager.startUpdatingLocation()
                model.pollDriveRecord()
            }
            model.refreshRide(delay: 3, showFinish: true)
        case .finished, .cancelled:
            print("#K_ ride finished or canceled!")
            mapView.clear()
            if status == .finished {
                actionButton.setTitle(type == .ride ? "You've arrived!!" : "Driver has arrived!!", for: .normal)
            } else {
                actionButton.setTitle("Service cancelled!", for: .normal)
            }
            actionButton.isEnabled = true
            isPollingDriveRecord = false
            destination = nil
            userLocation = nil
            driverLocation = nil
            driverMarker?.map = nil
            driverMarker = nil
        default:
            defaultStatusActions()
        }
    }
    
    private func defaultStatusActions() {
        actionButton.setTitle(destination == nil ? "Home Service" : "Ride Service", for: .normal)
        actionButton.isEnabled = true
        clearButton.setTitle("Clear", for: .normal)
        clearButton.isEnabled = true
        clearButton.isHidden = false
        if buttonContainerView.arrangedSubviews.count == 1 {
            buttonContainerView.addArrangedSubview(clearButton)
        }
        
        isPollingDriveRecord = false
    }
    
    private func addMarker(coordinate: CLLocationCoordinate2D, title: String? = nil, snippet: String? = nil) {
        let marker = GMSMarker(position: coordinate)
        marker.title = title
        marker.snippet = snippet
        marker.map = mapView
    }

    @IBAction func onClickClearButton(_ sender: Any) {
        switch status {
        case .unassigned, .assigning:
            print("post cancel ride request")
            let alert = UIAlertController(title: "Cancel Request", message: "Are you sure to cancel current request?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes, cancel it", style: .destructive, handler: { action in
                self.model.cancelRide()
            }))
            alert.addAction(UIAlertAction(title: "No", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        case .defaultStatus:
            destination = nil
            userLocation = nil
            mapView.clear()
            reloadData()
        case .cancelled, .finished:
            mapView.clear()
            status = .defaultStatus
        default:
            print("Clear button action error, no actions available for status: \(status)")
        }
    }
    
    @IBAction func onClickActionButton(_ sender: Any) {
        if status == .cancelled || status == .finished {
            mapView.clear()
            status = .defaultStatus
            return
        }
        guard status == .defaultStatus, let currentLocation = currentLocation else {
            return
        }
        type = destination == nil ? .home : .ride
        guard type == .home || (type == .ride && destination != nil) else {
            return
        }
        let origin = type == .home ? nil : currentLocation
        let dest = type == .home ? currentLocation.coordinate : destination
        model.createRide(type: type.rawValue, origin: origin, destination: dest!)
    }
    
    // Populate the array with the list of likely places.
    private func listLikelyPlaces() {
      // Clean up from previous sessions.
      likelyPlaces.removeAll()

      let placeFields: GMSPlaceField = [.name, .coordinate]
      placesClient.findPlaceLikelihoodsFromCurrentLocation(withPlaceFields: placeFields) { (placeLikelihoods, error) in
        guard error == nil else {
          // TODO: Handle the error.
          print("Current Place error: \(error!.localizedDescription)")
          return
        }

        guard let placeLikelihoods = placeLikelihoods else {
          print("No places found.")
          return
        }

        // Get likely places and add to the list.
        for likelihood in placeLikelihoods {
          let place = likelihood.place
          self.likelyPlaces.append(place)
        }
      }
    }
}

// Delegates to handle events for the location manager.
extension MapsViewController: CLLocationManagerDelegate {

  // Handle incoming location events.
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let location: CLLocation = locations.last!
    currentLocation = location
    print("Location: \(location)")

    let zoomLevel = locationManager.accuracyAuthorization == .fullAccuracy ? preciseLocationZoomLevel : approximateLocationZoomLevel
    let camera = GMSCameraPosition.camera(withLatitude: location.coordinate.latitude,
                                          longitude: location.coordinate.longitude,
                                          zoom: zoomLevel)

    if mapView.isHidden {
      mapView.isHidden = false
      mapView.camera = camera
    } else {
      mapView.animate(to: camera)
    }

    listLikelyPlaces()
  }

  // Handle authorization for the location manager.
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    // Check accuracy authorization
    let accuracy = manager.accuracyAuthorization
    switch accuracy {
    case .fullAccuracy:
        print("Location accuracy is precise.")
    case .reducedAccuracy:
        print("Location accuracy is not precise.")
    @unknown default:
      fatalError()
    }

    // Handle authorization status
    switch status {
    case .restricted:
      print("Location access was restricted.")
    case .denied:
      print("User denied access to location.")
      // Display the map using the default location.
      mapView.isHidden = false
    case .notDetermined:
      print("Location status not determined.")
    case .authorizedAlways: fallthrough
    case .authorizedWhenInUse:
      print("Location status is OK.")
        locationManager.startUpdatingLocation()
    @unknown default:
      fatalError()
    }
  }

  // Handle location manager errors.
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    locationManager.stopUpdatingLocation()
    print("Error: \(error)")
  }
}

extension MapsViewController: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
        mapView.clear()
        addMarker(coordinate: coordinate)
        destination = coordinate
        reloadData()
    }
}

extension MapsViewController: MapsModelDelegate {
    func updateDriverRecord(record: DriveRecord?) {
        if isPollingDriveRecord {
            if let record = record {
                driverLocation = Utils.decodeLocationString(location: record.driver_location)
            } else {
                driverLocation = nil
                driverMarker?.map = nil
                driverMarker = nil
            }
            model.pollDriveRecord()
        }
    }
    
    func createRideOnComplete(ride: Ride?) {
        // show ride
        guard let ride = ride else {
            status = .defaultStatus
            return
        }
        type = OrderType(rawValue: ride.type ) ?? .ride
        guard let _ = currentLocation, let dest = self.destination ?? Utils.decodeLocationString(location: ride.destination) else {
            return
        }
        status = OrderStatus(rawValue: ride.status ) ?? .defaultStatus
        guard ride.status < OrderStatus.finished.rawValue, type == .ride, let userLocationString = ride.user_location, let userLocation = Utils.decodeLocationString(location: userLocationString) else {
            return
        }
        if self.destination == nil || self.userLocation == nil {
            self.destination = dest
            self.userLocation = userLocation
            DispatchQueue.main.async {
                self.addMarker(coordinate: dest)
            }
            model.requestDirection(origin: userLocation, dest: dest)
        }
    }
    
    func updateDirectionPolyline(path: Array<String>) {
        // update direction path
        DispatchQueue.main.async {
            for p in path {
                let path = GMSMutablePath(fromEncodedPath: p)
                let polyline = GMSPolyline(path: path)
                
                polyline.strokeWidth = 5
                polyline.strokeColor = .blue
                polyline.map = self.mapView
            }
        }
    }
}

extension MapsViewController: LoginModelDelegate {
    func redirectToLoginViewController() {
        let loginViewController = LoginViewController(nibName: "LoginViewController", bundle: nil)
        loginViewController.onCompleteBlock = {
            self.model.checkIfCurrentRideAvailable()
        }
        let navigationController = UINavigationController(rootViewController: loginViewController)
        
        DispatchQueue.main.async {
            navigationController.popToRootViewController(animated: true)
            if (!navigationController.isViewLoaded
                    || navigationController.view.window == nil) {
                print("to login controller")
                navigationController.isModalInPresentation = true
                self.present(navigationController,
                             animated: true,
                             completion: nil)
            }
        }
    }
}

