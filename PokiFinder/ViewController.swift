//
//  ViewController.swift
//  PokiFinder
//
//  Created by Badr Moh on 14.07.17.
//  Copyright © 2017 Badr Moh. All rights reserved.
//

import UIKit
import MapKit
import Firebase

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource {

    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet var popUp: UIView!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var mapView: MKMapView!
    let location = CLLocationManager()
    var userLocationUpdatedOnce = false
    var geoFire: GeoFire!
    var geoFireRef: FIRDatabaseReference!
    var effect: UIVisualEffect!
    var selectedRow: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        effect = blurView.effect
        blurView.effect = nil
        blurView.isHidden = true
        
        pickerView.showsSelectionIndicator = true
        pickerView.dataSource = self
        pickerView.delegate = self
        
        mapView.delegate = self
        mapView.userTrackingMode = MKUserTrackingMode.follow
        
        location.delegate = self
//        location.desiredAccuracy = kCLLocationAccuracyBest
//        location.requestWhenInUseAuthorization()
//        location.startMonitoringSignificantLocationChanges()
        
        //Initialize the GeoFire object.
        geoFireRef = FIRDatabase.database().reference()
        geoFire = GeoFire(firebaseRef: geoFireRef)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updataLocationStatus()
    }
    
    //Get the authorization.
    func updataLocationStatus () {
        
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        } else {
            location.requestWhenInUseAuthorization()
        }
    }
    
    //Update location on MapView when a change in authorization happens.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        } else {
            updataLocationStatus()
        }
    }
    
    //Center the Map at a given location.
    func updateLocationOnMap (Location: CLLocation) {
        
        let coordinates = MKCoordinateRegionMakeWithDistance(Location.coordinate, 2000, 2000)
        mapView.setRegion(coordinates, animated: true)
    }
    
    //Center the Map at user location at the app start
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
        if let loc = userLocation.location {
            if !userLocationUpdatedOnce {
                updateLocationOnMap(Location: loc)
                userLocationUpdatedOnce =  true
            }
        }
    }
    
    //Update the image of user location at Map.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let pokIdentifier = "Pokemon"
        var annotationView : MKAnnotationView?
        
        if annotation.isKind(of: MKUserLocation.self) {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "User")
            annotationView?.image = UIImage(named: "ash")
        } else if let deqAnn = mapView.dequeueReusableAnnotationView(withIdentifier: pokIdentifier) {
            annotationView = deqAnn
            annotationView?.annotation = annotation
        } else {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: pokIdentifier)
            annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }
        
        if let annotationView = annotationView, let annotation = annotation as? PokAnnotation {
            annotationView.canShowCallout = true
            annotationView.image = UIImage(named: String(annotation.pokId))
            print(annotation.pokId)
            let btn = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            btn.setImage(UIImage(named: "map"), for: .normal)
            annotationView.rightCalloutAccessoryView = btn
        }
        
        return annotationView
    }
    
    //Set location for a given pokemon
    func setPokAtLocation (forLocation location: CLLocation, withPokemon pokId: Int){
        
        geoFire.setLocation(location, forKey: "\(pokId)")
    }
    
    //Query for pokemons for a given location and set their annotations at the mapView
    func queryAndAnnotatePok (forLocation location: CLLocation) {
        
        let query = geoFire.query(at: location, withRadius: 2.5)
        _ = query?.observe(.keyEntered, with: { (key, location) in
            if let key = key, let location = location {
                let anno = PokAnnotation(coordinate: location.coordinate, pokId: Int(key)!)
                self.mapView.addAnnotation(anno)
            }
        })
    }
    
    //Update View with the new pokemons when panning or zooming.
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        
        let location = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        queryAndAnnotatePok(forLocation: location)
    }
    
    //Define what happens when user clicks on annotation callback accessory.
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        if let annotation = view.annotation as? PokAnnotation {
            let place = MKPlacemark(coordinate: annotation.coordinate)
            let destination = MKMapItem(placemark: place)
            destination.name = "Pokemon here!"
            let regionDistance: CLLocationDistance = 2000
            let regionSpan = MKCoordinateRegionMakeWithDistance(annotation.coordinate, regionDistance, regionDistance)
            let options = [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
                           MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span),
                           MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking] as [String : Any]
            MKMapItem.openMaps(with: [destination], launchOptions: options)
        }
    }

    
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        selectedRow = row
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pokemon[row].capitalized
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pokemon.count
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    //When the button is pressed, place a random pokemon in the current location
    @IBAction func addRandPok(_ sender: Any) {
        
        
        
//        let rand = arc4random_uniform(151) + 1
//
        
        //Show the POPUP menu
        popUp.layer.cornerRadius = 0.8
        popUp.center = view.center
        self.view.addSubview(popUp)
        popUp.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        popUp.alpha = 0
        
        UIView.animate(withDuration: 0.2, animations: {
            self.blurView.isHidden = false
            self.blurView.effect = self.effect
            self.popUp.alpha = 1
            self.popUp.transform = CGAffineTransform(scaleX: 1.0, y: 0.1)
            UIView.animate(withDuration: 0.6, animations: {
                self.popUp.transform = CGAffineTransform.identity
            })
        
        })
    }
    
    
    
    
    @IBAction func selectPokemonPressed(_ sender: Any) {
        
        let location = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        if let row = selectedRow {
            setPokAtLocation(forLocation: location, withPokemon: row+1)
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.popUp.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
            self.popUp.alpha = 0
            self.blurView.effect = nil
        }) { (success:Bool) in
            self.popUp.removeFromSuperview()
            self.blurView.isHidden = true
        }
        
    }
}




















