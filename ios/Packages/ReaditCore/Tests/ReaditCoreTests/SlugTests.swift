import XCTest
@testable import ReaditCore

final class SlugTests: XCTestCase {
    func testPunctuationCollapsesToSingleDash() {
        XCTAssertEqual(
            Slug.slugify("Minions: Stripe's one-shot, end-to-end coding agents"),
            "minions-stripe-s-one-shot-end-to-end-coding-agents"
        )
    }

    func testEmptyAndSymbolOnlyTitlesYieldEmpty() {
        XCTAssertEqual(Slug.slugify(""), "")
        XCTAssertEqual(Slug.slugify("!!!---"), "")
    }

    func testTruncationAt80Bytes() {
        let title = String(repeating: "a", count: 200)
        let slug = Slug.slugify(title)
        XCTAssertLessThanOrEqual(slug.utf8.count, 80)
        XCTAssertFalse(slug.hasSuffix("-"))
    }
}
