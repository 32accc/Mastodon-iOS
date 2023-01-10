//
//  MastodonSDK+API+AppTests.swift
//  
//
//  Created by MainasuK Cirno on 2021/1/29.
//

import os.log
import XCTest
import Combine
@testable import MastodonSDK

extension MastodonSDKTests {
    
    func testCreateAnApplication() throws {
        try _testCreateAnApplication(domain: domain)
    }
    
    func _testCreateAnApplication(domain: String) throws {
        let theExpectation = expectation(description: "Create An Application")
        
        let query = Mastodon.API.App.CreateQuery(
            clientName: "XCTest",
            redirectURIs: "mastodon://joinmastodon.org/oauth",
            website: nil
        )
        Mastodon.API.App.create(session: session, domain: domain, query: query)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                case .finished:
                    break
                }
            } receiveValue: { response in
                XCTAssertEqual(response.value.name, "XCTest")
                XCTAssertEqual(response.value.website, nil)
                XCTAssertEqual(response.value.redirectURI, "urn:ietf:wg:oauth:2.0:oob")
                os_log("%{public}s[%{public}ld], %{public}s: (%s) clientID %s", ((#file as NSString).lastPathComponent), #line, #function, domain, response.value.clientID ?? "nil")
                os_log("%{public}s[%{public}ld], %{public}s: (%s) clientSecret %s", ((#file as NSString).lastPathComponent), #line, #function, domain, response.value.clientSecret ?? "nil")
                theExpectation.fulfill()
            }
            .store(in: &disposeBag)
        
        wait(for: [theExpectation], timeout: 5.0)
    }

}

extension MastodonSDKTests {
    
    func testVerifyAppCredentials() throws {
        try _testVerifyAppCredentials(domain: domain, accessToken: testToken)
    }
    
    func _testVerifyAppCredentials(domain: String, accessToken: String) throws {
        let theExpectation = expectation(description: "Verify App Credentials")
        
        let authorization = Mastodon.API.OAuth.Authorization(accessToken: accessToken)
        Mastodon.API.App.verifyCredentials(
            session: session,
            domain: domain,
            authorization: authorization
        )
        .receive(on: DispatchQueue.main)
        .sink { completion in
            switch completion {
            case .failure(let error):
                XCTFail(error.localizedDescription)
            case .finished:
                break
            }
        } receiveValue: { response in
            XCTAssertEqual(response.value.name, "XCTest")
            XCTAssertEqual(response.value.website, nil)
            theExpectation.fulfill()
        }
        .store(in: &disposeBag)
        
        wait(for: [theExpectation], timeout: 5.0)
    }
    
}
