import XCTest
@testable import ReaditCore

final class HTMLToMarkdownTests: XCTestCase {
    private func md(_ html: String) throws -> String {
        try HTMLToMarkdown.convert(html)
    }

    func testHeadingsAllLevels() throws {
        for level in 1...6 {
            let out = try md("<h\(level)>Hi</h\(level)>")
            XCTAssertEqual(out, String(repeating: "#", count: level) + " Hi\n")
        }
    }

    func testParagraphCollapsesInlineWhitespace() throws {
        let out = try md("<p>Hello   \n  world</p>")
        XCTAssertEqual(out, "Hello world\n")
    }

    func testTwoParagraphsSeparatedByBlankLine() throws {
        let out = try md("<p>One</p><p>Two</p>")
        XCTAssertEqual(out, "One\n\nTwo\n")
    }

    func testStrongAndEmInlineMarkers() throws {
        let out = try md("<p>Be <strong>bold</strong> and <em>brave</em>.</p>")
        XCTAssertEqual(out, "Be **bold** and *brave*.\n")
    }

    func testLinkRendersAsMarkdown() throws {
        let out = try md(#"<p>See <a href="https://x.test">site</a>.</p>"#)
        XCTAssertEqual(out, "See [site](https://x.test).\n")
    }

    func testLinkWithoutHrefDegradesToText() throws {
        let out = try md("<p>See <a>label</a>.</p>")
        XCTAssertEqual(out, "See label.\n")
    }

    func testImageRendersWithAltAndSrc() throws {
        let out = try md(#"<p><img src="https://x.test/a.png" alt="cat"/></p>"#)
        XCTAssertEqual(out, "![cat](https://x.test/a.png)\n")
    }

    func testImageMissingSrcIsDropped() throws {
        let out = try md(#"<p>before<img alt="x"/>after</p>"#)
        XCTAssertEqual(out, "beforeafter\n")
    }

    func testUnorderedList() throws {
        let out = try md("<ul><li>a</li><li>b</li></ul>")
        XCTAssertEqual(out, "- a\n- b\n")
    }

    func testOrderedList() throws {
        let out = try md("<ol><li>a</li><li>b</li><li>c</li></ol>")
        XCTAssertEqual(out, "1. a\n2. b\n3. c\n")
    }

    func testInlineCode() throws {
        let out = try md("<p>Use <code>x &lt; y</code> here.</p>")
        XCTAssertEqual(out, "Use `x < y` here.\n")
    }

    func testPreCodeBlockPreservesLineBreaks() throws {
        let out = try md("<pre><code>line1\nline2</code></pre>")
        XCTAssertEqual(out, "```\nline1\nline2\n```\n")
    }

    func testBlockquotePrefixesEachLine() throws {
        let out = try md("<blockquote><p>line one</p><p>line two</p></blockquote>")
        XCTAssertEqual(out, "> line one\n> \n> line two\n")
    }

    func testHorizontalRule() throws {
        let out = try md("<p>before</p><hr/><p>after</p>")
        XCTAssertEqual(out, "before\n\n---\n\nafter\n")
    }

    func testLineBreakInParagraph() throws {
        let out = try md("<p>one<br/>two</p>")
        XCTAssertEqual(out, "one  \ntwo\n")
    }

    func testUnknownTagRendersChildrenInline() throws {
        let out = try md("<p>hello <span>world</span></p>")
        XCTAssertEqual(out, "hello world\n")
    }

    func testBoldEmptyContentIsDropped() throws {
        let out = try md("<p>x<strong></strong>y</p>")
        XCTAssertEqual(out, "xy\n")
    }
}
