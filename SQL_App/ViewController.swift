//
//  ViewController.swift
//  SQL_App
//
//  Created by Angela Liu on 6/25/16.
//  Copyright © 2016 amliu. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Messing with SQLite
        SQLiteDatabase.create()
        
        guard let connection = try? SQLiteDatabase.open() else {
           return
        }
        connection.getPlaces("14:00", longitude: 50, latitude: 900, radius: 100)
        
        connection.close()
        
        
    }
    
    @IBAction func get() {
        guard let connection = try? SQLiteDatabase.open() else {
            return
        }
//        connection.getPlaces(50, latitude: 100, radius: 100)
        connection.close()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

