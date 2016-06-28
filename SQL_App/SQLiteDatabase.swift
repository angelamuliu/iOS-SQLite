//
//  SQLiteDatabase.swift
//  SQL_App
//
//  Created by Angela Liu on 6/25/16.
//  Copyright © 2016 amliu. All rights reserved.
//

// STEPS TO ADD FRAMEWORKLESS C API SQLite SUPPORT
// 1. In app > build settings, add "./SQL_App/BridgingHeader.h" to the setting "Objective-C Bridging Header"
// 2. Create the file itself, have it have "#import <sqlite3.h>" somewhere
// 3. Go to app, scroll to bottom, to "Linked Frameworks and Libraries" press plus and add "libsqlite3.0tbd"
// Now you can use it, without any need of "import" anywhere

// About bridging headers AKA exposing C functionality with Swift -> https://developer.apple.com/library/ios/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html
// About getting sqlite to work in Swift -> http://stackoverflow.com/questions/24102775/accessing-an-sqlite-database-in-swift

// Based off code/tutorial, extended for our own needs
// https://www.raywenderlich.com/123579/sqlite-tutorial-swift

import Foundation

enum SQLiteError: ErrorType {
    case OpenDatabase(message: String)
    case Prepare(message: String)
    case Step(message: String)
    case Bind(message: String)
}

/**
 Handles querying, maintaining, etc of the database
*/
class SQLiteDatabase {
    private let dbPointer: COpaquePointer
    
    private init(dbPointer: COpaquePointer) {
        self.dbPointer = dbPointer
    }
    
    deinit {
        sqlite3_close(dbPointer)
    }
    
    /**
     Opens a connection to the database and returns a SQLiteDatabase
     object to use to mess with the database
     */
    static func open() throws -> SQLiteDatabase {
        let fileManager = NSFileManager.defaultManager()
        let path = fileManager.currentDirectoryPath // Make db in project root
        var db: COpaquePointer = nil
        
        if sqlite3_open("/Users/Angela/Programming/iOS_Swift/SmallProjects/SQL_App/SQL_App/db.sqlite", &db) == SQLITE_OK {
            return SQLiteDatabase(dbPointer: db)
        } else {
            defer { // Defer is a new control that happens always AFTER this block is done executing
                // About defer, see: http://nshipster.com/guard-and-defer/
                if db != nil {
                    sqlite3_close(db)
                }
            }
            // So this error handling below will happen first, before the defer block
            if let message = String.fromCString(sqlite3_errmsg(db)) {
                throw SQLiteError.OpenDatabase(message: message)
            } else {
                throw SQLiteError.OpenDatabase(message: "No error message provided from sqlite.")
            }
        }
    }
    
    func close() {
        print("Closing connection. Thanks!")
        sqlite3_close(dbPointer)
    }
    
    
    // ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- -----
    // STATIC FUNCTIONS - DB MAINTENANCE
    // Used to manage the database itself (e.g. dropping, recreating, connecting
    // ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- -----
    
    /** 
     Creates the database. (If one exists already, drops it and recreates)
    */
    static func create() -> Void {
        print("Dropping existing database...")
        drop("/Users/Angela/Programming/iOS_Swift/SmallProjects/SQL_App/SQL_App/db.sqlite")
        
        print("Creating database...")
        var db: COpaquePointer = nil
        if sqlite3_open("/Users/Angela/Programming/iOS_Swift/SmallProjects/SQL_App/SQL_App/db.sqlite", &db) == SQLITE_OK {
            print("Successfully opened connection to database")
            migrateTables(db)
            populate(db)
        }
        defer { sqlite3_close(db) }
    }

    /**
     Destroys the database
     */
    static private func drop(db_path:String?) {
        if let unwrapped_path = db_path {
            do {
                if NSFileManager.defaultManager().fileExistsAtPath(unwrapped_path) {
                    try NSFileManager.defaultManager().removeItemAtPath(unwrapped_path)
                }
            } catch {
                print("Could not destroy database file")
            }
        }
    }
    
    /**
     Creates tables in the database
    */
    static private func migrateTables(db: COpaquePointer) {
        let createPlace: String = "CREATE TABLE Place(Id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL," +
            "Longitude FLOAT, Latitude FLOAT, Category CHARACTER(255)," +
            "Subcategory CHARACTER(255), Name CHARACTER(255)," +
            "Address VARCHAR(255), Phone CHARACTER(255), Open_hour TIME," +
            "Close_hour TIME, Image_url VARCHAR(255), Tags VARCHAR(255)" +
        ");"
        var createPlaceStatement: COpaquePointer = nil
        sqlite3_prepare_v2(db, createPlace, -1, &createPlaceStatement, nil)
        sqlite3_step(createPlaceStatement)
        sqlite3_finalize(createPlaceStatement)
        
    }
    
    /**
     Reads from a JSON file to add in records
    */
    static private func populate(db:COpaquePointer) {
        if let path = NSBundle.mainBundle().pathForResource("data", ofType: "json") {
            let jsonData:NSData = NSData(contentsOfFile: path)!
            do {
                let jsonDict = try NSJSONSerialization.JSONObjectWithData(jsonData, options: NSJSONReadingOptions.AllowFragments) as! NSDictionary
                let placesArr = jsonDict.valueForKey("Places") as! NSArray
                insertPlaces(db, placesArr: placesArr)
            } catch { }
        }
    }
    
    /**
     Given content from the JSON, inserts a place
    */
    static private func insertPlaces(db:COpaquePointer, placesArr : NSArray) {
        let insertStatementString = "INSERT INTO Place (Longitude,Latitude,Category,Subcategory,Name,Address,Phone,Open_hour,Close_hour,Image_url,Tags)" +
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);"
        var insertStatement: COpaquePointer = nil
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            for place in placesArr {
                let placeDict = place as! NSDictionary
                sqlite3_bind_double(insertStatement, 1, placeDict.valueForKey("Longitude") as! Double)
                sqlite3_bind_double(insertStatement, 2, placeDict.valueForKey("Latitude") as! Double)
                sqlite3_bind_text(insertStatement, 3, (placeDict.valueForKey("Category")?.UTF8String)!, -1, nil)
                sqlite3_bind_text(insertStatement, 4, (placeDict.valueForKey("Subcategory")?.UTF8String)!, -1, nil)
                sqlite3_bind_text(insertStatement, 5, (placeDict.valueForKey("Name")?.UTF8String)!, -1, nil)
                sqlite3_bind_text(insertStatement, 6, (placeDict.valueForKey("Address")?.UTF8String)!, -1, nil)
                sqlite3_bind_text(insertStatement, 7, (placeDict.valueForKey("Phone")?.UTF8String)!, -1, nil)
                
                // Inserting time AKA Sqlite actually doesn't have a time class: http://stackoverflow.com/questions/1933720/how-do-i-insert-datetime-value-into-a-sqlite-database
                sqlite3_bind_text(insertStatement, 8, (placeDict.valueForKey("Open_hour")?.UTF8String)!, -1, nil)
                sqlite3_bind_text(insertStatement, 9, (placeDict.valueForKey("Close_hour")?.UTF8String)!, -1, nil)
                sqlite3_bind_text(insertStatement, 10, (placeDict.valueForKey("Image_url")?.UTF8String)!, -1, nil)
                
                sqlite3_bind_text(insertStatement, 11, (placeDict.valueForKey("Tags") as! NSArray).componentsJoinedByString(" "), -1 ,nil)
                
                if sqlite3_step(insertStatement) == SQLITE_DONE {
                    print("Successfully inserted row.")
                } else {
                    print("Could not insert row.")
                }
                sqlite3_reset(insertStatement) // Get ready for next insert
            }
            sqlite3_finalize(insertStatement)
        } else {
            print(sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil))
            print("Could not prepare statement")
        }
    }
    
    // ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- -----
    // QUERY / ETC ...
    // Uses an instance of a connection to the db
    // ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- ----- -----

    private var errorMessage: String {
        if let errorMessage = String.fromCString(sqlite3_errmsg(dbPointer)) {
            return errorMessage
        } else {
            return "No error message provided from sqlite."
        }
    }

    func prepareStatement(sql: String) throws -> COpaquePointer {
        var statement: COpaquePointer = nil
        guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.Prepare(message: errorMessage)
        }
        return statement
    }
    
    /**
      Given a longitude, latitude, and search radius, and current time (in string format e.g. '0:20'), 
      returns (roughly) all open places within the radius... though as a square
    */
    func getPlaces(time:String, longitude:Float, latitude:Float, radius:Float) -> [Place] {
        var placesArr = [Place]()
        let querySql = "SELECT * FROM Place WHERE Longitude BETWEEN ? AND ? AND Latitude BETWEEN ? AND ? AND ? BETWEEN Open_hour AND Close_hour;"

        guard let queryStatement = try? prepareStatement(querySql) else { // If the statement after guard fails, we stop trying to get altogether
            return []
        }
        
        defer { sqlite3_finalize(queryStatement) }
        
        let longitude_start = longitude - radius
        let longitude_end = longitude + radius
        let latitude_start = latitude - radius
        let latitude_end = latitude + radius
        
        sqlite3_bind_double(queryStatement, 1, Double(longitude_start))
        sqlite3_bind_double(queryStatement, 2, Double(longitude_end))
        sqlite3_bind_double(queryStatement, 3, Double(latitude_start))
        sqlite3_bind_double(queryStatement, 4, Double(latitude_end))
        sqlite3_bind_text(queryStatement, 5, time.cStringUsingEncoding(NSUTF8StringEncoding)!, -1, nil)
        
        while(true) {
            guard sqlite3_step(queryStatement) == SQLITE_ROW else { // Stop looping when we step and it's not another record
                break
            }
            // This looks terrible... 
            let row_id:Int = Int(sqlite3_column_int(queryStatement, 0))
            let row_longitude:Float = Float(sqlite3_column_double(queryStatement, 1))
            let row_latitude:Float = Float(sqlite3_column_double(queryStatement, 2))
            let row_category = String.fromCString(UnsafePointer<CChar>(sqlite3_column_text(queryStatement, 3)))
            let row_subcategory = String.fromCString(UnsafePointer<CChar>(sqlite3_column_text(queryStatement, 4)))
            let row_name = String.fromCString(UnsafePointer<CChar>(sqlite3_column_text(queryStatement, 5)))
            let row_address = String.fromCString(UnsafePointer<CChar>(sqlite3_column_text(queryStatement, 6)))
            let row_phone = String.fromCString(UnsafePointer<CChar>(sqlite3_column_text(queryStatement, 7)))
            let row_open_hour = String.fromCString(UnsafePointer<CChar>(sqlite3_column_text(queryStatement, 8)))
            let row_close_hour = String.fromCString(UnsafePointer<CChar>(sqlite3_column_text(queryStatement, 9)))
            let row_image_url = String.fromCString(UnsafePointer<CChar>(sqlite3_column_text(queryStatement, 10)))
            let row_tags = String.fromCString(UnsafePointer<CChar>(sqlite3_column_text(queryStatement, 11)))
            
            placesArr.append(Place(id: row_id, longitude: row_longitude, latitude: row_latitude, category: row_category, subcategory: row_subcategory, name: row_name, address: row_address, phone: row_phone, open_hour: row_open_hour, close_hour: row_close_hour, image_url: row_image_url, tags: row_tags))
        }
        return placesArr
    }
    
    

}
