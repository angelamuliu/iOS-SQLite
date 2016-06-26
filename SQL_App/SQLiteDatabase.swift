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
    
    
    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

}
