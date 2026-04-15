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

    /// После успешного Supabase `signIn` в Core Data есть `PlayerProfile` (merge из `profiles`), но записи `User` с `email` часто нет — без этого `fetchUser(byEmail:)` не находит пользователя.
    /// Создаём/обновляем локальный `User` с тем же `userId`, что и у профиля Supabase, и связываем с `PlayerProfile`.
    func upsertUserForSupabaseLogin(
        userId: UUID,
        email: String,
        passwordHash: String,
        preferredUsername: String
    ) -> User? {
        let context = container.viewContext

        if let existing = fetchUser(byId: userId) {
            existing.email = email
            existing.passwordHash = passwordHash
            if let profile = fetchPlayerProfile(byProfileId: userId) {
                profile.user = existing
                existing.playerProfile = profile
            }
            saveContext()
            return existing
        }

        if let emailOwner = fetchUser(byEmail: email), emailOwner.userId != userId {
            debugLog("upsertUserForSupabaseLogin: email уже занят другим userId (локально) — конфликт с Supabase \(userId)")
            return nil
        }

        var username = preferredUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.isEmpty { username = "user" }
        if let other = fetchUser(byUsername: username), other.userId != userId {
            username = "\(username)_\(String(userId.uuidString.prefix(8)))"
        }

        let user = User(context: context)
        user.userId = userId
        user.username = username
        user.email = email
        user.passwordHash = passwordHash
        user.createdAt = Date()
        user.subscriptionStatus = "free"

        if let profile = fetchPlayerProfile(byProfileId: userId) {
            profile.user = user
            user.playerProfile = profile
        } else if let profile = fetchPlayerProfile(byUserId: userId) {
            profile.user = user
            user.playerProfile = profile
        }

        saveContext()
        return user
    }
    
    func setSuperAdmin(username: String, isSuperAdmin: Bool) {
        guard let user = fetchUser(byUsername: username) else { return }
        user.isSuperAdmin = isSuperAdmin
        saveContext()
    }
}
