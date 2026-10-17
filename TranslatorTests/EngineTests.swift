import Foundation
import Testing
@testable import Translator

private let english = LanguageCatalog.english
private let vietnamese = LanguageCatalog.vietnamese

struct GoogleCloudEngineTests {
    @Test func v3RequestTargetsProjectWithKeyHeader() throws {
        let request = try GoogleCloudEngine.makeRequest(text: "Hello", source: "en", target: "vi", apiKey: " key123 ",
                                                        version: .v3, projectID: "my-proj")
        #expect(request.url?.absoluteString == "https://translation.googleapis.com/v3/projects/my-proj:translateText")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "key123")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["contents"] as? [String] == ["Hello"])
        #expect(body["sourceLanguageCode"] as? String == "en")
        #expect(body["targetLanguageCode"] as? String == "vi")
        #expect(body["mimeType"] as? String == "text/plain")
    }

    @Test func v3RequestWithoutProjectIsNotConfigured() {
        #expect(throws: TranslationError.notConfigured(.google)) {
            try GoogleCloudEngine.makeRequest(text: "x", source: "en", target: "vi", apiKey: "k", version: .v3, projectID: " ")
        }
        #expect(!GoogleCloudEngine.isConfigured(apiKey: "k", version: .v3, projectID: ""))
        #expect(GoogleCloudEngine.isConfigured(apiKey: "k", version: .v2, projectID: ""))
        #expect(!GoogleCloudEngine.isConfigured(apiKey: "", version: .v2, projectID: ""))
    }

    @Test func v2RequestUsesBasicEndpoint() throws {
        let request = try GoogleCloudEngine.makeRequest(text: "Hello", source: "en", target: "vi", apiKey: "k",
                                                        version: .v2, projectID: "")
        #expect(request.url == GoogleCloudEngine.v2Endpoint)
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["q"] as? [String] == ["Hello"])
        #expect(body["source"] as? String == "en")
        #expect(body["target"] as? String == "vi")
        #expect(body["format"] as? String == "text")
    }

    @Test func parsesV3Response() throws {
        let json = #"{"translations":[{"translatedText":"Xin chào","detectedLanguageCode":""}]}"#
        #expect(try GoogleCloudEngine.parseResponse(Data(json.utf8), status: 200, version: .v3) == "Xin chào")
    }

    @Test func parsesV2ResponseAndDecodesEntities() throws {
        let json = #"{"data":{"translations":[{"translatedText":"Tom&#39;s &amp; Jerry&#8217;s"}]}}"#
        #expect(try GoogleCloudEngine.parseResponse(Data(json.utf8), status: 200, version: .v2) == "Tom's & Jerry’s")
    }

    @Test func surfacesGoogleErrorMessage() {
        let json = #"{"error":{"code":403,"message":"API keys are not supported by this API.","status":"PERMISSION_DENIED"}}"#
        #expect(throws: TranslationError.http(.google, status: 403, message: "API keys are not supported by this API.")) {
            try GoogleCloudEngine.parseResponse(Data(json.utf8), status: 403, version: .v3)
        }
    }

    @Test func rejectsMalformedResponse() {
        #expect(throws: TranslationError.invalidResponse(.google)) {
            try GoogleCloudEngine.parseResponse(Data("{}".utf8), status: 200, version: .v3)
        }
    }
}

struct DeepLEngineTests {
    @Test func freeKeysUseFreeHost() {
        #expect(DeepLEngine.endpoint(for: "abc:fx") == DeepLEngine.freeHost)
        #expect(DeepLEngine.endpoint(for: "abc") == DeepLEngine.proHost)
    }

    @Test func mapsGoogleCodesToDeepLCodes() {
        #expect(DeepLEngine.sourceCode(for: "en") == "EN")
        #expect(DeepLEngine.targetCode(for: "en") == "EN-US")
        #expect(DeepLEngine.targetCode(for: "vi") == "VI")
        #expect(DeepLEngine.sourceCode(for: "zh-CN") == "ZH")
        #expect(DeepLEngine.targetCode(for: "zh-CN") == "ZH-HANS")
        #expect(DeepLEngine.targetCode(for: "zh-TW") == "ZH-HANT")
        #expect(DeepLEngine.targetCode(for: "pt") == "PT-BR")
        #expect(DeepLEngine.sourceCode(for: "pt-PT") == "PT")
        #expect(DeepLEngine.sourceCode(for: "iw") == "HE")
        #expect(DeepLEngine.sourceCode(for: "no") == "NB")
        #expect(DeepLEngine.sourceCode(for: "fil") == "TL")
        #expect(DeepLEngine.sourceCode(for: "yua") == nil)   // Yucatec Maya: Google only
        #expect(DeepLEngine.targetCode(for: "haw") == nil)
    }

    @Test func requestHasAuthHeaderAndBody() throws {
        let request = try DeepLEngine.makeRequest(text: "Hello", source: "en", target: "vi", apiKey: "k:fx")
        #expect(request.url == DeepLEngine.freeHost)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "DeepL-Auth-Key k:fx")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["text"] as? [String] == ["Hello"])
        #expect(body["source_lang"] as? String == "EN")
        #expect(body["target_lang"] as? String == "VI")
    }

    @Test func unsupportedPairFailsBeforeTheNetwork() {
        #expect(throws: TranslationError.unsupportedPair(.deepL)) {
            try DeepLEngine.makeRequest(text: "x", source: "yua", target: "vi", apiKey: "k")
        }
    }

    @Test func parsesResponseAndErrors() throws {
        let ok = #"{"translations":[{"detected_source_language":"EN","text":"Xin chào"}]}"#
        #expect(try DeepLEngine.parseResponse(Data(ok.utf8), status: 200) == "Xin chào")
        #expect(throws: TranslationError.http(.deepL, status: 456, message: "Character quota exceeded for this billing period.")) {
            try DeepLEngine.parseResponse(Data(#"{"message":"Quota Exceeded"}"#.utf8), status: 456)
        }
        #expect(throws: TranslationError.http(.deepL, status: 400, message: "Value for 'target_lang' not supported.")) {
            try DeepLEngine.parseResponse(Data(#"{"message":"Value for 'target_lang' not supported."}"#.utf8), status: 400)
        }
        #expect(throws: TranslationError.invalidResponse(.deepL)) {
            try DeepLEngine.parseResponse(Data(#"{"translations":[]}"#.utf8), status: 200)
        }
    }
}

struct AppleEngineTests {
    @Test func mapsGoogleCodesToAppleLanguages() {
        #expect(AppleEngine.language(for: "zh-CN").script?.identifier == "Hans")
        #expect(AppleEngine.language(for: "zh-TW").script?.identifier == "Hant")
        #expect(AppleEngine.language(for: "iw").languageCode?.identifier == "he")
        #expect(AppleEngine.language(for: "pt").region?.identifier == "BR")
        #expect(AppleEngine.language(for: "vi").languageCode?.identifier == "vi")
    }

    @Test func supportMatchesByLanguageAndScript() {
        let supported = ["en-US", "en-GB", "zh-Hans-CN", "zh-Hant-TW", "vi-VN", "pt-BR"].map { Locale.Language(identifier: $0) }
        #expect(AppleEngine.isSupported(AppleEngine.language(for: "en"), in: supported))
        #expect(AppleEngine.isSupported(AppleEngine.language(for: "zh-CN"), in: supported))
        #expect(AppleEngine.isSupported(AppleEngine.language(for: "vi"), in: supported))
        #expect(!AppleEngine.isSupported(AppleEngine.language(for: "yua"), in: supported))
        let codes = AppleEngine.supportedCodes(in: LanguageCatalog.all, supported: supported)
        #expect(codes.isSuperset(of: ["en", "zh-CN", "zh-TW", "vi", "pt"]))
        #expect(!codes.contains("fr"))
    }
}

/// A canned engine for router tests.
private struct StubEngine: TranslationEngine {
    let id: EngineID
    var result: Result<String, TranslationError>
    var delay: Duration = .zero

    func translate(_ text: String, from source: Language, to target: Language) async throws -> String {
        if delay > .zero { try await Task.sleep(for: delay) }
        return try result.get()
    }
}

struct EngineRouterTests {
    @Test func planFollowsModeAndConfiguration() {
        #expect(EngineRouter.plan(for: .init(mode: .auto, googleConfigured: true, deepLConfigured: true)) == [.google, .deepL, .apple])
        #expect(EngineRouter.plan(for: .init(mode: .auto, googleConfigured: false, deepLConfigured: true)) == [.deepL, .apple])
        #expect(EngineRouter.plan(for: .init(mode: .auto, googleConfigured: false, deepLConfigured: false)) == [.apple])
        #expect(EngineRouter.plan(for: .init(mode: .google, googleConfigured: false, deepLConfigured: false)) == [.google])
        #expect(EngineRouter.plan(for: .init(mode: .deepL, googleConfigured: true, deepLConfigured: true)) == [.deepL])
        #expect(EngineRouter.plan(for: .init(mode: .apple, googleConfigured: true, deepLConfigured: true)) == [.apple])
    }

    @Test func fallsBackOnEverythingButCancellation() {
        #expect(EngineRouter.shouldFallBack(after: TranslationError.offline))
        #expect(EngineRouter.shouldFallBack(after: TranslationError.timeout(.google)))
        #expect(EngineRouter.shouldFallBack(after: TranslationError.http(.google, status: 403, message: "")))
        #expect(EngineRouter.shouldFallBack(after: TranslationError.unsupportedPair(.deepL)))
        #expect(!EngineRouter.shouldFallBack(after: TranslationError.cancelled))
        #expect(!EngineRouter.shouldFallBack(after: CancellationError()))
    }

    @Test func autoFallsThroughToTheNextEngine() async throws {
        let router = EngineRouter(engines: [
            .google: StubEngine(id: .google, result: .failure(.http(.google, status: 500, message: "boom"))),
            .deepL: StubEngine(id: .deepL, result: .success("DeepL says hi")),
            .apple: StubEngine(id: .apple, result: .success("Apple says hi")),
        ])
        let result = try await router.translate("hi", from: english, to: vietnamese,
                                                configuration: .init(mode: .auto, googleConfigured: true, deepLConfigured: true))
        #expect(result == TranslationResult(text: "DeepL says hi", engine: .deepL))
    }

    @Test func autoTimesOutSlowCloudEngines() async throws {
        var router = EngineRouter(engines: [
            .google: StubEngine(id: .google, result: .success("late"), delay: .seconds(2)),
            .apple: StubEngine(id: .apple, result: .success("Apple says hi")),
        ])
        router.cloudTimeout = .milliseconds(50)
        let result = try await router.translate("hi", from: english, to: vietnamese,
                                                configuration: .init(mode: .auto, googleConfigured: true, deepLConfigured: false))
        #expect(result.engine == .apple)
    }

    @Test func explicitModeReportsItsOwnError() async {
        let router = EngineRouter(engines: [
            .google: StubEngine(id: .google, result: .failure(.notConfigured(.google))),
            .apple: StubEngine(id: .apple, result: .success("Apple says hi")),
        ])
        await #expect(throws: TranslationError.notConfigured(.google)) {
            try await router.translate("hi", from: english, to: vietnamese,
                                       configuration: .init(mode: .google, googleConfigured: false, deepLConfigured: false))
        }
    }

    @Test func lastEngineErrorIsReported() async {
        let router = EngineRouter(engines: [
            .apple: StubEngine(id: .apple, result: .failure(.notInstalled)),
        ])
        await #expect(throws: TranslationError.notInstalled) {
            try await router.translate("hi", from: english, to: vietnamese,
                                       configuration: .init(mode: .auto, googleConfigured: false, deepLConfigured: false))
        }
    }

    @Test func mapsTransportErrors() {
        #expect(TranslationError.from(URLError(.notConnectedToInternet), engine: .google) == .offline)
        #expect(TranslationError.from(URLError(.timedOut), engine: .deepL) == .timeout(.deepL))
        #expect(TranslationError.from(URLError(.cancelled), engine: .deepL) == .cancelled)
        #expect(TranslationError.from(CancellationError(), engine: .google) == .cancelled)
        #expect(TranslationError.from(TranslationError.notInstalled, engine: .google) == .notInstalled)
    }
}
