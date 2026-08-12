import XCTest
@testable import Breathlet

final class AppLanguageTests: XCTestCase {
    func testRawValueParsing() {
        XCTAssertEqual(AppLanguage(rawValue: "system"), .system)
        XCTAssertEqual(AppLanguage(rawValue: "english"), .english)
        XCTAssertEqual(AppLanguage(rawValue: "simplifiedChinese"), .simplifiedChinese)
        XCTAssertNil(AppLanguage(rawValue: "bogus"))
    }

    func testAppleLanguagesValue() {
        XCTAssertNil(AppLanguage.system.appleLanguagesValue)
        XCTAssertEqual(AppLanguage.english.appleLanguagesValue, "en")
        XCTAssertEqual(AppLanguage.simplifiedChinese.appleLanguagesValue, "zh-Hans")
    }
}
