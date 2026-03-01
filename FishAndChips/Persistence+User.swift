import CoreData

// MARK: - User Management
extension PersistenceController {
    func createUser(username: String, passwordHash: String, email: String? = nil) -> User? {
        let context = container.viewContext

        if fetchUser(byUsername: username) != nil {
            debugLog("Error creating user: username '\(username)' already exists")
            return nil
        }
        
        if let email = email, !email.isEmpty {
            if fetchUser(byEmail: email) != nil {
                debugLog("Error creating user: email '\(email)' already exists")
                return nil
            }
        }

        let user = User(context: context)
        user.userId = UUID()
        user.username = username
        user.passwordHash = passwordHash
        user.email = email
        user.createdAt = Date()
        user.subscriptionStatus = "free"

        do {
            try context.save()
            return user
        } catch {
            debugLog("Error creating user: \(error)")
            return nil
        }
    }

    func fetchUser(byUsername username: String) -> User? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "username == %@", username)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            debugLog("Error fetching user: \(error)")
            return nil
        }
    }
    
    func fetchUser(byEmail email: String) -> User? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "email ==[c] %@", email)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            debugLog("Error fetching user by email: \(error)")
            return nil
        }
    }

    func fetchUser(byId userId: UUID) -> User? {
        let context = container.viewContext
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            debugLog("Error fetching user: \(error)")
            return nil
        }
    }

    func updateUserLastLogin(_ user: User) {
        user.lastLoginAt = Date()
        saveContext()
    }

    func updateUserSubscription(_ user: User, status: String, expiresAt: Date?) {
        user.subscriptionStatus = status
        user.subscriptionExpiresAt = expiresAt
        saveContext()
    }
    
    func updateUsername(_ user: User, newUsername: String) -> Bool {
        if let existingUser = fetchUser(byUsername: newUsername),
           existingUser.userId != user.userId {
            return false
        }
        user.username = newUsername
        saveContext()
        return true
    }
    
    func setSuperAdmin(username: String, isSuperAdmin: Bool) {
        guard let user = fetchUser(byUsername: username) else { return }
        user.isSuperAdmin = isSuperAdmin
        saveContext()
    }
}
