//
//  AuthManager.swift
//  SpotifyApp
//
//  Created by Tommy on 2/12/23.
//

import Foundation

final class AuthManager{
    static let shared = AuthManager()
    
    private var refreshingToken = false
    
    private init() {}
    
    struct Constants{
        static let clientID = "875fa8902efa4b21b8efff6e004f6f18"
        static let clientSecret = "22382788bfd24bdcb96961a208deaec6"
        static let tokenAPIURL = "https://accounts.spotify.com/api/token"
        static let redirectURI = "https://github.com/sessiyevat/UIKit-Apps"
        static let scope = "user-read-private%20playlist-modify-public%20playlist-read-private%20playlist-modify-private%20user-follow-read%20user-library-modify%20user-library-read%20user-read-email"
    }
    
    public var signInURL: URL? {
        let base = "https://accounts.spotify.com/authorize"
        let string = "\(base)?response_type=code&client_id=\(Constants.clientID)&scope=\(Constants.scope)&redirect_uri=\(Constants.redirectURI)&show_dialog=TRUE"
        
        return URL(string: string)
    }
    
    var isSignedIn: Bool {
        return accessToken != nil
    }
    
    private var accessToken: String? {
        return UserDefaults.standard.string(forKey: "access_token")
    }
    
    private var refreshToken: String? {
        return UserDefaults.standard.string(forKey: "refresh_token")
    }
    
    private var tokenExpirationDate: Date? {
        return UserDefaults.standard.object(forKey: "expirationDate") as? Date
    }
    
    private var shouldRefreshToken: Bool {
        guard let expirationDate = tokenExpirationDate else {return false}
        let currentDate = Date()
        let fiveMinutes: TimeInterval = 300
        return currentDate.addingTimeInterval(fiveMinutes) >= expirationDate
    }
    
    public func exchangeCodeForToken(code: String, completion: @escaping ((Bool) -> Void)){
        guard let url = URL(string: Constants.tokenAPIURL) else {return}
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type",
                         value: "authorization_code"),
            URLQueryItem(name: "code",
                         value: code),
            URLQueryItem(name: "redirect_uri",
                         value: Constants.redirectURI)
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.query?.data(using: .utf8)
        
        let basicToken = Constants.clientID + ":" + Constants.clientSecret
        let data = basicToken.data(using: .utf8)
        guard let base64 = data?.base64EncodedString() else {
            completion(false)
            return
        }
        
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data , error == nil else {
                completion(false)
                return
            }
            
            do {
                let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                self?.cacheToken(result: result)
                completion(true)
            } catch {
                print(error.localizedDescription)
                completion(false)
            }
        }
        
        task.resume()
        
    }
    
    private var onRefreshBlocks = [((String) -> Void)]()
    
    // Supplies valid token to be used with API Calls
    public func withValidToken(completion: @escaping (String) -> Void){
        guard !refreshingToken else {
            onRefreshBlocks.append(completion)
            return
        }
        
        if shouldRefreshToken {
            refreshIfNeeded { [weak self] success in
                if let token = self?.accessToken , success {
                    completion(token)
                }
            }
        } else if let token = accessToken {
            completion(token)
        }
    }
    
    public func refreshIfNeeded(completion: ((Bool) -> Void)? ){
        guard !refreshingToken else {
            return
        }
        
        guard shouldRefreshToken else {
            completion?(true)
            return
        }
        guard let refreshToken = self.refreshToken else {
            return
        }
        
        //Refreshing token
        guard let url = URL(string: Constants.tokenAPIURL) else {return}
        
        refreshingToken = true
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type",
                         value: "refresh_token"),
            URLQueryItem(name: "refresh_token",
                         value: refreshToken)
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.query?.data(using: .utf8)
        
        let basicToken = Constants.clientID + ":" + Constants.clientSecret
        let data = basicToken.data(using: .utf8)
        guard let base64 = data?.base64EncodedString() else {
            completion?(false)
            return
        }
        
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data , error == nil else {
                completion?(false)
                return
            }
            
            do {
                let result = try JSONDecoder().decode(AuthResponse.self, from: data)
                self?.onRefreshBlocks.forEach { $0(result.access_token)}
                self?.onRefreshBlocks.removeAll()
                self?.cacheToken(result: result)
//                print("Successfully refreshed")
                completion?(true)
            } catch {
                print(error.localizedDescription)
                completion?(false)
            }
        }
        
        task.resume()
    }
    
    public func cacheToken(result: AuthResponse){
        UserDefaults.standard.set(result.access_token, forKey: "access_token")
        if let refresh_token = result.refresh_token {
            UserDefaults.standard.set(refresh_token, forKey: "refresh_token")
        }
        UserDefaults.standard.set(Date().addingTimeInterval(TimeInterval(result.expires_in)), forKey: "expirationDate")
    }

    public func signOut(completion: (Bool) -> Void){
        UserDefaults.standard.set(nil, forKey: "access_token")
        UserDefaults.standard.set(nil, forKey: "refresh_token")
        UserDefaults.standard.set(nil, forKey: "expirationDate")
        completion(true)
        
    }
}
