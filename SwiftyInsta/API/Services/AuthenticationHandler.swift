//
//  AuthenticationHandler.swift
//  SwiftyInsta
//
//  Created by Stefano Bertagno on 23/07/2019.
//  Copyright © 2019 Mahdi. All rights reserved.
//

import Foundation

class AuthenticationHandler: Handler {
    // MARK: Log in
    func authenticate(cache: SessionCache, completionHandler: @escaping (Result<Login.Response, Error>) -> Void) {
        // update handler.
        handler.settings.device = cache.device
        handler.response = .init(model: .pending, cache: cache)
        do {
            try requests.setCookies(cache.cookies)
            // fetch the user.
            handler.users.current(delay: 0...0) { [weak self] in
                switch $0 {
                case .success(let user):
                    // update user info alone.
                    self?.handler.response?.cache?.storage?.user = user
                    completionHandler(.success(.init(model: .success, cache: cache)))
                case .failure(let error): completionHandler(.failure(error))
                }
            }
        } catch {
            completionHandler(.failure(AuthenticationError.invalidCache))
        }
    }

    func authenticate(user: Credentials, completionHandler: @escaping (Result<(Login.Response, APIHandler), Error>) -> Void) {
        // update user.
        var user = user
        user.handler = handler
        // remove cookies.
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        // ask for login.
        requests.fetch(method: .get, url: Result { try URLs.home() }) { [weak self] in
            guard let me = self, let handler = me.handler else { return completionHandler(.failure(GenericError.weakObjectReleased)) }
            // analyze response.
            switch $0 {
            case .failure(let error): handler.settings.queues.response.async { completionHandler(.failure(error)) }
            case .success(_, let response) where response != nil:
                let response = response!
                // obtain cookies.
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: response.allHeaderFields as? [String: String] ?? [:],
                                                 for: response.url!)
                guard let csrfToken = cookies.first(where: { $0.name == "csrftoken" })?.value else {
                    return handler.settings.queues.response.async {
                        completionHandler(.failure(GenericError.custom("Invalid cookies.")))
                    }
                }
                user.csrfToken = csrfToken
                // prepare body.
                let body = ["username": user.username, "password": user.password]
                let headers = ["X-Instagram-AJAX": "1",
                               "X-CSRFToken": csrfToken,
                               "X-Requested-With": "XMLHttpRequest",
                               "Referer": "https://instagram.com/"]
                me.requests.decode(CredentialsAuthenticationResponse.self,
                                   method: .post,
                                   url: Result { try URLs.login() },
                                   body: .parameters(body),
                                   headers: headers,
                                   checkingValidStatusCode: false,
                                   delay: 0...0) {
                                    switch $0 {
                                    case .failure(let error):
                                        handler.settings.queues.response.async {
                                            completionHandler(.failure(error))
                                        }
                                    case .success(let response):
                                        // check for status.
                                        if let url = try? response.checkpointUrl.flatMap(URLs.checkpoint) {
                                            user.completionHandler = completionHandler
                                            user.response = .challenge(url)
                                            me.challengeInfo(for: user) { form in
                                                handler.settings.queues.response.async {
                                                    completionHandler(.failure(AuthenticationError.checkpoint(suggestions: form?.suggestion)))
                                                }
                                            }
                                            // ask for verification code.
                                            me.challenge(csrfToken: csrfToken, url: url, verification: user.verification) {
                                                completionHandler(.failure($0))
                                            }
                                        } else if let identifier = response.twoFactorInfo?.twoFactorIdentifier {
                                            user.completionHandler = completionHandler
                                            user.response = .twoFactor(identifier)
                                            handler.settings.queues.response.async {
                                                completionHandler(.failure(AuthenticationError.twoFactor))
                                            }
                                        } else if let authentication = response.authenticated {
                                            // check for authentication status.
                                            if authentication, let dsUserId = response.userId {
                                                user.response = .success
                                                // create session cache.
                                                let cookies = HTTPCookieStorage.shared
                                                    .cookies?.filter { $0.domain.contains(".instagram.com") } ?? []
                                                let storage = SessionStorage(dsUserId: dsUserId,
                                                                             user: nil,
                                                                             csrfToken: csrfToken,
                                                                             sessionId: cookies.first(where: { $0.name == "sessionid" })!.value,
                                                                             rankToken: dsUserId+"_"+handler.settings.device.phoneGuid.uuidString)
                                                let cache = SessionCache(storage: storage,
                                                                         device: handler.settings.device,
                                                                         cookies: cookies.cookieData)
                                                // actually authenticate.
                                                handler.authenticate(with: .cache(cache), completionHandler: completionHandler)
                                            } else if response.user ?? false {
                                                user.response = .failure
                                                handler.settings.queues.response.async {
                                                    completionHandler(.failure(AuthenticationError.invalidPassword))
                                                }
                                            } else {
                                                user.response = .failure
                                                handler.settings.queues.response.async {
                                                    completionHandler(.failure(AuthenticationError.invalidUsername))
                                                }
                                            }
                                        } else {
                                            user.response = .failure
                                            handler.settings.queues.response.async {
                                                completionHandler(.failure(GenericError.custom("Unknown error.")))
                                            }
                                        }
                                    }
                }
            default:
                user.response = .failure
                handler.settings.queues.response.async {
                    completionHandler(.failure(GenericError.custom("Invalid response.")))
                }
            }
        }
    }

    func challenge(csrfToken: String,
                   url: URL,
                   verification: Credentials.Verification,
                   completionHandler: @escaping (Error) -> Void) {
        // prepare body.
        let body = ["choice": verification.rawValue]
        let headers = ["X-CSRFToken": csrfToken,
                       "X-Requested-With": "XMLHttpRequest",
                       "Referer": url.absoluteString,
                       "X-Instagram-AJAX": "1"]

        requests.fetch(method: .post,
                       url: url,
                       body: .parameters(body),
                       headers: headers,
                       delay: 0...0) { [weak self] in
                        guard let me = self, let handler = me.handler else { return completionHandler(GenericError.weakObjectReleased) }
                        switch $0 {
                        case .failure(let error):
                            handler.settings.queues.response.async {
                                completionHandler(error)
                            }
                        case .success(let data, _) where data != nil:
                            let data = data!
                            let string = String(data: data, encoding: .utf8)!
                            // check for error.
                            if string.contains("Enter the 6-digit code")
                                || string.contains("Enter Your Security Code")
                                || string.contains("VerifySMSCodeForm")
                                || string.contains("VerifyEmailCodeForm") {
                                // no need to notify anything, it's already been done.
                                return
                            }
                            // notify errors.
                            handler.settings.queues.response.async {
                                completionHandler(GenericError.custom("Invalid response."))
                            }
                        default:
                            handler.settings.queues.response.async {
                                completionHandler(GenericError.custom("Invalid response."))
                            }
                        }
        }
    }

    func challengeInfo(for user: Credentials, completionHandler: @escaping (ChallengeForm?) -> Void) {
        guard case .challenge(let url) = user.response else { return completionHandler(nil) }
        requests.fetch(method: .get, url: url) { [weak self] in
            guard let me = self, let handler = me.handler else { return completionHandler(nil) }
            switch $0 {
            case .success(let data, _) where data != nil:
                let data = data!
                let string = String(data: data, encoding: .utf8)!
                guard string.contains("window._sharedData = ") else { return completionHandler(nil) }
                // parse.
                let dataPartOne = string.components(separatedBy: "window._sharedData = ")[1]
                let rawData = dataPartOne.components(separatedBy: ";</script>")[0]
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let decoded = try? decoder.decode(ChallengeForm.self, from: rawData.data(using: .utf8)!)
                completionHandler(decoded)
            default:
                handler.settings.queues.response.async {
                    completionHandler(nil)
                }
            }
        }
    }

    func code(for credentials: Credentials) {
        guard let code = credentials.code,
            credentials.csrfToken != nil,
            let completionHandler = credentials.completionHandler else {
                return print("Invalid setup.")
        }
        // check for response.
        switch credentials.response {
        case .success, .failure, .unknown:
            handler.settings.queues.response.async {
                completionHandler(.failure(GenericError.custom("No code required.")))
            }
        case .challenge(let url):
            send(challengeCode: code, at: url, for: credentials, completionHandler: completionHandler)
        case .twoFactor(let identifier):
            send(twoFactorCode: code, with: identifier, for: credentials, completionHandler: completionHandler)
        }
    }

    func send(challengeCode code: String,
              at url: URL,
              for user: Credentials,
              completionHandler: @escaping (Result<(Login.Response, APIHandler), Error>) -> Void) {
        var user = user
        let body = ["security_code": code]
        let headers = ["X-CSRFToken": user.csrfToken!,
                       "X-Requested-With": "XMLHttpRequest",
                       "Referer": url.absoluteString,
                       "X-Instagram-AJAX": "1"]

        requests.fetch(method: .post, url: url, body: .parameters(body), headers: headers, delay: 0...0) { [weak self] in
            guard let me = self, let handler = me.handler else { return completionHandler(.failure(GenericError.weakObjectReleased)) }
            // check for response.
            switch $0 {
            case .failure(let error):
                handler.settings.queues.response.async {
                    completionHandler(.failure(error))
                }
            case .success(let data, _) where data != nil:
                let data = data!
                let string = String(data: data, encoding: .utf8)!
                // check for redirect.
                if string.contains("CHALLENGE_REDIRECTION") {
                    if string.contains("instagram://checkpoint/dismiss") {
                        me.afterCheckpointAuthenticate(user: user, completionHandler: completionHandler)
                    } else {
                        user.response = .success
                        // create session cache.
                        let cookies = HTTPCookieStorage.shared.cookies?.filter { $0.domain.contains(".instagram.com") } ?? []
                        let dsUserId = cookies.first(where: { $0.name == "ds_user_id" })!.value
                        let storage = SessionStorage(dsUserId: dsUserId,
                                                     user: nil,
                                                     csrfToken: user.csrfToken ?? cookies.first(where: { $0.name == "csrftoken" })!.value,
                                                     sessionId: cookies.first(where: { $0.name == "sessionid" })!.value,
                                                     rankToken: dsUserId+"_"+handler.settings.device.phoneGuid.uuidString)
                        let cache = SessionCache(storage: storage,
                                                 device: handler.settings.device,
                                                 cookies: cookies.cookieData)
                        handler.authenticate(with: .cache(cache), completionHandler: completionHandler)
                    }
                } else {
                    handler.settings.queues.response.async {
                        completionHandler(.failure(GenericError.custom("Invalid response.")))
                    }
                }
            default:
                handler.settings.queues.response.async {
                    completionHandler(.failure(GenericError.custom("Invalid response.")))
                }
            }
        }
    }

    func send(twoFactorCode code: String,
              with identifier: String,
              for user: Credentials,
              completionHandler: @escaping (Result<(Login.Response, APIHandler), Error>) -> Void) {
        // guard for url.
        guard let url = try? URLs.twoFactor().absoluteString else { return completionHandler(.failure(GenericError.invalidUrl)) }
        var user = user
        let body = ["username": user.username,
                    "verificationCode": code,
                    "identifier": identifier]
        let headers = ["X-CSRFToken": user.csrfToken!,
                       "X-Requested-With": "XMLHttpRequest",
                       "Referer": url,
                       "X-Instagram-AJAX": "1"]

        requests.fetch(method: .post,
                       url: Result { try URLs.twoFactor() },
                       body: .parameters(body),
                       headers: headers,
                       delay: 0...0) { [weak self] in
                        guard let me = self, let handler = me.handler else { return completionHandler(.failure(GenericError.weakObjectReleased)) }
                        // check for response.
                        switch $0 {
                        case .failure(let error):
                            handler.settings.queues.response.async {
                                completionHandler(.failure(error))
                            }
                        case .success(_, let response) where response != nil:
                            let response = response!
                            switch response.statusCode {
                            case 200:
                                // log in.
                                user.response = .success
                                // create session cache.
                                let cookies = HTTPCookieStorage.shared.cookies?.filter { $0.domain.contains(".instagram.com") } ?? []
                                let dsUserId = cookies.first(where: { $0.name == "ds_user_id" })!.value
                                let storage = SessionStorage(dsUserId: dsUserId,
                                                             user: nil,
                                                             csrfToken: user.csrfToken ?? cookies.first(where: { $0.name == "csrftoken" })!.value,
                                                             sessionId: cookies.first(where: { $0.name == "sessionid" })!.value,
                                                             rankToken: dsUserId+"_"+handler.settings.device.phoneGuid.uuidString)
                                let cache = SessionCache(storage: storage,
                                                         device: handler.settings.device,
                                                         cookies: cookies.cookieData)
                                handler.authenticate(with: .cache(cache), completionHandler: completionHandler)
                            case 400:
                                user.response = .failure
                                handler.settings.queues.response.async {
                                    completionHandler(.failure(GenericError.custom("Invalid code.")))
                                }
                            default:
                                user.response = .failure
                                handler.settings.queues.response.async {
                                    completionHandler(.failure(GenericError.custom("Invalid response.")))
                                }
                            }
                        default:
                            user.response = .failure
                            handler.settings.queues.response.async {
                                completionHandler(.failure(GenericError.custom("Invalid response.")))
                            }
                        }
        }
    }

    func afterCheckpointAuthenticate(user: Credentials, completionHandler: @escaping (Result<(Login.Response, APIHandler), Error>) -> Void) {
        var user = user
        let body = ["username": user.username,
                    "password": user.password]
        let headers = ["X-Instagram-AJAX": "1",
                       "X-CSRFToken": user.csrfToken!,
                       "X-Requested-With": "XMLHttpRequest",
                       "Referer": "https://instagram.com/"]

        requests.fetch(method: .post, url: Result { try URLs.login() }, body: .parameters(body), headers: headers) { [weak self] in
            guard let me = self, let handler = me.handler else { return completionHandler(.failure(GenericError.weakObjectReleased)) }
            // check for response.
            switch $0 {
            case .failure(let error):
                handler.settings.queues.response.async {
                    completionHandler(.failure(error))
                }
            case .success(let data, _) where data != nil:
                let data = data!
                let string = String(data: data, encoding: .utf8)!
                if string.contains("two_factor_required") {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    guard let decoded = try? decoder.decode(CredentialsAuthenticationResponse.self, from: data) else {
                        return completionHandler(.failure(GenericError.custom("Invalid response.")))
                    }
                    user.code = nil
                    user.response = .twoFactor(decoded.twoFactorInfo!.twoFactorIdentifier!)
                    // ask for code.
                    handler.settings.queues.response.async {
                        completionHandler(.failure(AuthenticationError.twoFactor))
                    }
                } else if string.contains("checkpoint_required") {
                    user.response = .failure
                    handler.settings.queues.response.async {
                        completionHandler(.failure(AuthenticationError.checkpointLoop))
                    }
                } else {
                    // log in.
                    user.response = .success
                    // create session cache.
                    let cookies = HTTPCookieStorage.shared.cookies?.filter { $0.domain.contains(".instagram.com") } ?? []
                    let dsUserId = cookies.first(where: { $0.name == "ds_user_id" })!.value
                    let storage = SessionStorage(dsUserId: dsUserId,
                                                 user: nil,
                                                 csrfToken: user.csrfToken ?? cookies.first(where: { $0.name == "csrftoken" })!.value,
                                                 sessionId: cookies.first(where: { $0.name == "sessionid" })!.value,
                                                 rankToken: dsUserId+"_"+handler.settings.device.phoneGuid.uuidString)
                    let cache = SessionCache(storage: storage,
                                             device: handler.settings.device,
                                             cookies: cookies.cookieData)
                    handler.authenticate(with: .cache(cache), completionHandler: completionHandler)
                }
            default:
                handler.settings.queues.response.async {
                    completionHandler(.failure(GenericError.custom("Invalid response.")))
                }
            }
        }
    }

    // MARK: Log out
    func invalidate(completionHandler: @escaping (Result<Bool, Error>) -> Void) {
        guard handler.user != nil else {
            return handler.settings.queues.response.async {
                completionHandler(.failure(GenericError.custom("User is not logged in.")))
            }
        }
        handler.requests.fetch(method: .post, url: Result { try URLs.getLogoutUrl() }) { [weak self] in
            guard let handler = self?.handler else { return completionHandler(.failure(GenericError.weakObjectReleased)) }
            let result = $0.flatMap { data, response -> Result<Bool, Error> in
                do {
                    guard let data = data, response?.statusCode == 200 else { throw GenericError.custom("Invalid response.") }
                    // decode data.
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decoded = try decoder.decode(Status.self, from: data)
                    return .success(decoded.state == .ok)
                } catch { return .failure(error) }
            }
            handler.settings.queues.response.async { completionHandler(result) }
        }
    }
}
