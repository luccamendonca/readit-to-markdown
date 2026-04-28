import XCTest
@testable import ReaditCore

final class FrontmatterTests: XCTestCase {
    func testReadTimeAppearsAfterURL() {
        let article = Article(
            title: "Title",
            summary: "summary",
            date: "2026-04-28",
            url: "https://example.com",
            body: "body text\n"
        )
        let out = Frontmatter.build(article, readTime: 7)
        XCTAssertTrue(out.contains("read_time: 7\n"))
        let urlIdx = out.range(of: "url:")!.lowerBound
        let rtIdx = out.range(of: "read_time:")!.lowerBound
        XCTAssertLessThan(urlIdx, rtIdx)
    }

    func testEmptyDateRendersNull() {
        let article = Article(title: "T", summary: "", date: "", url: "https://x", body: "b")
        let out = Frontmatter.build(article, readTime: 0)
        XCTAssertTrue(out.contains("date: null\n"))
        XCTAssertTrue(out.contains("summary: \"\"\n"))
    }

    func testEscapesQuotesAndBackslashes() {
        XCTAssertEqual(Frontmatter.yamlEscape("a \"b\" c"), "a \\\"b\\\" c")
        XCTAssertEqual(Frontmatter.yamlEscape("a\\b"), "a\\\\b")
        XCTAssertEqual(Frontmatter.yamlEscape("a\nb"), "a b")
    }
}
