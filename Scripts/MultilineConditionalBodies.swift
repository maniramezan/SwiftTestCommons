import Foundation
import SwiftParser
import SwiftSyntax

final class MultilineConditionalBodies: SyntaxVisitor {
    private let locations: SourceLocationConverter
    private(set) var insertions: Set<Int> = []
    private(set) var violations: [SourceLocation] = []

    init(tree: SourceFileSyntax, path: String) {
        locations = SourceLocationConverter(fileName: path, tree: tree)
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind {
        guard node.parent?.is(GuardStmtSyntax.self) == true || node.parent?.is(IfExprSyntax.self) == true,
            let first = node.statements.first?.firstToken(viewMode: .sourceAccurate),
            let last = node.statements.last?.lastToken(viewMode: .sourceAccurate)
        else {
            return .visitChildren
        }
        let opening = node.leftBrace.endPositionBeforeTrailingTrivia
        let closing = node.rightBrace.positionAfterSkippingLeadingTrivia
        var needsWrapping = false
        if locations.location(for: opening).line
            == locations.location(for: first.positionAfterSkippingLeadingTrivia).line
        {
            insertions.insert(opening.utf8Offset)
            needsWrapping = true
        }
        if locations.location(for: closing).line == locations.location(for: last.endPositionBeforeTrailingTrivia).line {
            insertions.insert(closing.utf8Offset)
            needsWrapping = true
        }
        if needsWrapping {
            violations.append(locations.location(for: node.leftBrace.positionAfterSkippingLeadingTrivia))
        }
        return .visitChildren
    }
}

func inspect(_ source: String, path: String) -> MultilineConditionalBodies {
    let tree = Parser.parse(source: source)
    let visitor = MultilineConditionalBodies(tree: tree, path: path)
    visitor.walk(tree)
    return visitor
}

func insertingNewlines(_ source: String, at offsets: Set<Int>) -> String {
    var bytes = Array(source.utf8)
    for offset in offsets.sorted(by: >) {
        bytes.insert(10, at: offset)
    }
    return String(decoding: bytes, as: UTF8.self)
}

func verifyConditionalBodies() {
    let cases: [(String, Int)] = [
        ("guard let fallback else { throw Failure() }", 1),
        ("if ready { run() } else { stop() }", 2),
        ("if ready { run() } else if waiting { wait() }", 2),
        ("if ready {\n    run()\n}", 0),
        ("if ready { run()\n}", 1),
        ("if ready {\n    run() }", 1),
        ("if items.contains(where: { $0.ready }) { run() }", 1),
        ("guard let value = items.first(where: { $0.ready }) else { return }", 1),
        ("let text = #\"if ready { run() }\"#\n// guard ready else { return }", 0),
        ("let value = if ready { 1 } else { 2 }", 2),
        ("let café = 1\nif ready { if waiting { wait() } }", 2),
        ("if ready {}\nlet callback = { run() }", 0),
    ]
    for (source, expected) in cases {
        let result = inspect(source, path: "fixture.swift")
        precondition(result.violations.count == expected, "Unexpected diagnostics for: \(source)")
        let fixed = insertingNewlines(source, at: result.insertions)
        precondition(inspect(fixed, path: "fixture.swift").violations.isEmpty, "Fix failed for: \(source)")
    }
    print("Verified \(cases.count) conditional-body fixtures")
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--self-test"] {
    verifyConditionalBodies()
} else {
    let fix = arguments.contains("--fix")
    let paths = arguments.filter { $0 != "--fix" }
    let roots = paths.isEmpty ? ["Package.swift", "Sources", "Tests", "Scripts"] : paths
    let markdown = try NSRegularExpression(pattern: "```swift\\n(.*?)\\n```", options: .dotMatchesLineSeparators)
    var failed = false
    for root in roots {
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root, isDirectory: &directory) else {
            fatalError("Missing path: \(root)")
        }
        let files: [String]
        if directory.boolValue {
            files = (FileManager.default.subpaths(atPath: root) ?? []).map { root + "/" + $0 }
        } else {
            files = [root]
        }
        for path in files.sorted() where path.hasSuffix(".swift") || path.hasSuffix(".md") {
            let source = try String(contentsOfFile: path, encoding: .utf8)
            let fragments: [(String, Int, Int)]
            if path.hasSuffix(".md") {
                fragments = markdown.matches(in: source, range: NSRange(source.startIndex..., in: source)).map {
                    match in
                    let range = Range(match.range(at: 1), in: source)!
                    let prefix = source[..<range.lowerBound]
                    return (String(source[range]), prefix.utf8.count, prefix.filter { $0 == "\n" }.count)
                }
            } else {
                fragments = [(source, 0, 0)]
            }
            var offsets: Set<Int> = []
            for (fragment, offset, lineOffset) in fragments {
                let result = inspect(fragment, path: path)
                for location in result.violations {
                    if !fix {
                        print(
                            "\(path):\(location.line + lineOffset):\(location.column): error: if and guard bodies must be multiline"
                        )
                        failed = true
                    }
                }
                offsets.formUnion(result.insertions.map { $0 + offset })
            }
            if fix && !offsets.isEmpty {
                try insertingNewlines(source, at: offsets).write(toFile: path, atomically: true, encoding: .utf8)
            }
        }
    }
    if failed {
        exit(1)
    }
}
