import XCTest
@testable import ReaditCore

final class ReadTimeTests: XCTestCase {
    func testEmpty() {
        XCTAssertEqual(ReadTime.minutes(body: ""), 0)
        XCTAssertEqual(ReadTime.minutes(body: "   \n\t  "), 0)
    }

    func testSingleWord() {
        XCTAssertEqual(ReadTime.minutes(body: "hello"), 1)
    }

    func testBoundaries() {
        let twoHundred = String(repeating: "word ", count: 200)
        let twoOhOne = String(repeating: "word ", count: 201)
        XCTAssertEqual(ReadTime.minutes(body: twoHundred), 1)
        XCTAssertEqual(ReadTime.minutes(body: twoOhOne), 2)
    }

    func testThousandWords() {
        XCTAssertEqual(ReadTime.minutes(body: String(repeating: "word ", count: 1000)), 5)
        XCTAssertEqual(ReadTime.minutes(body: String(repeating: "word ", count: 1001)), 6)
    }
}
