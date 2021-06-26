//
//  MapsViewController.swift
//  ENDEAVRide
//
//  Created by eavride on 6/1/21.
//

import UIKit
import GoogleMaps
import GooglePlaces

class MapsViewController: UIViewController {
    enum OrderStatus: Int {
        case defaultStatus = -1, unassigned = 0, assigning = 1, picking = 2, arrivedAtUserLocation = 3, started = 4, finished = 5, cancelled = 6
    }

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
            
            model.refreshRide(delay: 3)
        case .picking:
            print("#K_ driver picking user")
            actionButton.setTitle("Ride received, waiting for pick up...", for: .normal)
            actionButton.isEnabled = false
            clearButton.setTitle("Cancel", for: .normal)
            clearButton.isEnabled = false
            
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
            clearButton.setTitle("Cancel", for: .normal)
            clearButton.isEnabled = false
            
            isPollingDriveRecord = false
            model.refreshRide(delay: 5)
        case .started:
            print("#K_ user abord")
            actionButton.setTitle("Sit tight, heading to your destination!", for: .normal)
            actionButton.isEnabled = false
            clearButton.setTitle("Cancel", for: .normal)
            clearButton.isEnabled = false
            
            if (!isPollingDriveRecord) {
                isPollingDriveRecord = true
                print("#K_ start polling driver record")
                locationManager.startUpdatingLocation()
                model.pollDriveRecord()
            }
            model.refreshRide(delay: 3, showFinish: true)
        case .finished:
            print("#K_ ride finished!")
            defaultStatusActions()
        default:
            defaultStatusActions()
        }
    }
    
    private func defaultStatusActions() {
        actionButton.setTitle("Request Driver", for: .normal)
        actionButton.isEnabled = true
        clearButton.setTitle("Clear", for: .normal)
        clearButton.isEnabled = true
        
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
        case .defaultStatus:
            destination = nil
            userLocation = nil
            mapView.clear()
        default:
            print("Clear button action error, no actions available for status: \(status)")
        }
    }
    
    @IBAction func onClickActionButton(_ sender: Any) {
        guard status == .defaultStatus, let currentLocation = currentLocation, let dest = destination else {
            return
        }
        model.createRide(origin: currentLocation, destination: dest)
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
    }
}

extension MapsViewController: MapsModelDelegate {
    func updateDriverRecord(record: DriveRecord?) {
        if let record = record {
            driverLocation = Utils.decodeLocationString(location: record.driver_location)
        }
        
        if isPollingDriveRecord {
            model.pollDriveRecord()
        }
    }
    
    func createRideOnComplete(ride: Ride?) {
        // show ride
        guard let ride = ride else {
            status = .defaultStatus
            return
        }
        guard let _ = currentLocation, let dest = self.destination ?? Utils.decodeLocationString(location: ride.destination), let userLocation = Utils.decodeLocationString(location: ride.user_location) else {
            return
        }
        status = OrderStatus(rawValue: Int(ride.status) ?? -1) ?? .defaultStatus
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
//            self.actionButton.setTitle("Waiting Driver...", for: .normal)
//            self.actionButton.isEnabled = false
//            self.clearButton.setTitle("Cancel Request", for: .normal)
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

