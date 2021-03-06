import HTTP
import Authentication

let authAuthenticatedKey = "auth-authenticated"
let authHelperKey = "auth-helper"

public final class Helper {
    weak var request: Request?
    public init(request: Request) {
        self.request = request
    }
    
    internal func key<T>(for type: T.Type) -> String {
        return authAuthenticatedKey + "-\(T.self)"
    }

    /// Returns the `Authorization: ...` header
    // from the request.
    public var header: AuthorizationHeader? {
        guard let authorization = request?.headers["Authorization"] else {
            guard let query = request?.query else {
                return nil
            }
            
            if let bearer = query["_authorizationBearer"]?.string {
                return AuthorizationHeader(string: "Bearer \(bearer)")
            } else if let basic = query["_authorizationBasic"]?.string {
                return AuthorizationHeader(string: "Basic \(basic)")
            } else {
                return nil
            }
        }

        return AuthorizationHeader(string: authorization)
    }

    /// Authenticates an `Authenticatable` type.
    ///
    /// `isAuthenticated` will return `true` for this type
    public func authenticate<A: Authenticatable>(_ a: A) {
        request?.storage[key(for: A.self)] = a
    }

    /// Authenticates an `Authenticatable` and `Peristable` type
    /// giving the additional option to persist.
    ///
    /// Calls `.persist(for: req)` on the model.
    public func authenticate<AP: Authenticatable & Persistable>(_ ap: AP, persist: Bool) throws {
        request?.storage[key(for: AP.self)] = ap
        if persist {
            guard let request = request else {
                throw AuthError.noRequest
            }
            try ap.persist(for: request)
        }
    }

    /// Removes the authenticated user from internal storage.
    public func unauthenticate<A: Authenticatable>(_ a: A) throws {
        if
            let user = request?.storage[key(for: A.self)] as? Persistable,
            let req = request
        {
            try user.unpersist(for: req)
        }
        request?.storage[key(for: A.self)] = nil
    }

    /// Returns the Authenticated user if it exists.
    public func authenticated<A: Authenticatable>(_ userType: A.Type = A.self) -> A? {
        return request?.storage[key(for: A.self)] as? A
    }
    
    /// Returns the Authenticated user or throws if it does not exist.
    public func assertAuthenticated<A: Authenticatable>(_ userType: A.Type = A.self) throws -> A {
        guard let a = authenticated(A.self) else {
            throw AuthenticationError.notAuthenticated
        }

        return a
    }
    
    /// Returns true if the User type has been authenticated.
    public func isAuthenticated<A: Authenticatable>(_ userType: A.Type = A.self) -> Bool {
        return authenticated(A.self) != nil
    }
}

extension Request {
    /// Access the authorization helper with
    /// `authenticate` and `isAuthenticated` calls
    public var auth: Helper {
        if let existing = storage[authHelperKey] as? Helper {
            return existing
        }

        let helper = Helper(request: self)
        storage[authHelperKey] = helper

        return helper
    }
}
