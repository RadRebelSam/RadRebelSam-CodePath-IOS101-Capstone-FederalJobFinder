//
//  CoreDataStack.swift
//  usajobs
//
//  Created by Federal Job Finder on 11/13/25.
//

import CoreData
import Foundation
import Combine
import OSLog

/// Core Data stack management for the Federal Job Finder app
class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()

    private let inMemory: Bool
    private let logger = Logger(subsystem: "com.federaljobfinder.usajobs", category: "CoreData")

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FederalJobFinder")

        if inMemory {
            guard let description = container.persistentStoreDescriptions.first else {
                logger.error("No persistent store descriptions found for in-memory setup")
                return container
            }
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                self.logger.error("Core Data error: \(error.localizedDescription), userInfo: \(error.userInfo)")
                // For critical Core Data errors, we still need to handle this appropriately
                // In production, you might want to attempt recovery or clear corrupt data
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    /// Save changes to Core Data context asynchronously with proper error handling
    func save() async throws {
        let context = persistentContainer.viewContext

        guard context.hasChanges else { return }

        try await context.perform {
            do {
                try context.save()
                self.logger.info("Core Data save successful")
            } catch {
                self.logger.error("Core Data save error: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    /// Initialize with option for in-memory store (useful for testing)
    init(inMemory: Bool = false) {
        self.inMemory = inMemory
    }
    
    private convenience init() {
        self.init(inMemory: false)
    }
}