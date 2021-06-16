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

    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var buttonContainerView: UIStackView!
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    
    var mapView: GMSMapView!
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation?
    var placesClient: GMSPlacesClient!
    var preciseLocationZoomLevel: Float = 15.0
    var approximateLocationZoomLevel: Float = 10.0
    
    // An array to hold the list of likely places.
    var likelyPlaces: [GMSPlace] = []

    // The currently selected place.
    var selectedPlace: GMSPlace?
    var dest: CLLocationCoordinate2D?
    
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
    
    private func addMarker(coordinate: CLLocationCoordinate2D, title: String? = nil, snippet: String? = nil) {
        let marker = GMSMarker(position: coordinate)
            marker.title = title
            marker.snippet = snippet
            marker.map = mapView
    }

    @IBAction func onClickClearButton(_ sender: Any) {
        dest = nil
        mapView.clear()
    }
    
    @IBAction func onClickActionButton(_ sender: Any) {
        guard let currentLocation = currentLocation, let dest = dest else {
            return
        }
        model.createRide(origin: currentLocation, dest: dest)
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
        dest = coordinate
    }
}

extension MapsViewController: MapsModelDelegate {
    
    func createRideOnComplete(ride: Ride) {
        // show ride
        guard let currentLocation = currentLocation, let dest = self.dest ?? Utils.decodeRideDirection(direction: ride.direction) else {
            return
        }
        if self.dest == nil {
            self.dest = dest
            DispatchQueue.main.async {
                self.addMarker(coordinate: dest)
            }
        }
        model.requestDirection(origin: currentLocation, dest: dest)
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
            self.actionButton.setTitle("Waiting Driver...", for: .normal)
            self.actionButton.isEnabled = false
            self.clearButton.setTitle("Cancel Request", for: .normal)
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

