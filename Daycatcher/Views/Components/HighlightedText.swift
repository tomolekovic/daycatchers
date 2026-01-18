import SwiftUI

/// A text view that highlights matching search terms
struct HighlightedText: View {
    let text: String
    let searchTerm: String
    let textColor: Color
    let highlightColor: Color

    init(
        _ text: String,
        searchTerm: String,
        textColor: Color = .primary,
        highlightColor: Color = .yellow
    ) {
        self.text = text
        self.searchTerm = searchTerm
        self.textColor = textColor
        self.highlightColor = highlightColor
    }

    var body: some View {
        if searchTerm.isEmpty {
            Text(text)
                .foregroundStyle(textColor)
        } else {
            buildHighlightedText()
        }
    }

    @ViewBuilder
    private func buildHighlightedText() -> some View {
        let parts = splitTextBySearchTerm()

        if parts.count == 1 && !parts[0].isMatch {
            // No matches found
            Text(text).foregroundStyle(textColor)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    if part.isMatch {
                        Text(part.text)
                            .foregroundStyle(textColor)
                            .background(highlightColor.opacity(0.3))
                    } else {
                        Text(part.text)
                            .foregroundStyle(textColor)
                    }
                }
            }
        }
    }

    private struct TextPart {
        let text: String
        let isMatch: Bool
    }

    private func splitTextBySearchTerm() -> [TextPart] {
        var parts: [TextPart] = []
        let ranges = text.ranges(of: searchTerm, options: .caseInsensitive)

        if ranges.isEmpty {
            return [TextPart(text: text, isMatch: false)]
        }

        var currentIndex = text.startIndex

        for range in ranges {
            // Add text before the match
            if currentIndex < range.lowerBound {
                let beforeText = String(text[currentIndex..<range.lowerBound])
                parts.append(TextPart(text: beforeText, isMatch: false))
            }

            // Add the matched text
            let matchText = String(text[range])
            parts.append(TextPart(text: matchText, isMatch: true))

            currentIndex = range.upperBound
        }

        // Add remaining text after last match
        if currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex..<text.endIndex])
            parts.append(TextPart(text: remainingText, isMatch: false))
        }

        return parts
    }
}

// MARK: - String Extension for Finding Ranges

extension String {
    /// Find all ranges of a substring within the string
    func ranges(of searchString: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = startIndex

        while searchStartIndex < endIndex {
            guard let range = self.range(
                of: searchString,
                options: options,
                range: searchStartIndex..<endIndex
            ) else {
                break
            }

            ranges.append(range)
            searchStartIndex = range.upperBound
        }

        return ranges
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HighlightedText(
            "Hello World, hello again!",
            searchTerm: "hello",
            textColor: .primary,
            highlightColor: .yellow
        )

        HighlightedText(
            "This is a test string",
            searchTerm: "test",
            textColor: .primary,
            highlightColor: .blue
        )

        HighlightedText(
            "No matches here",
            searchTerm: "xyz",
            textColor: .primary,
            highlightColor: .yellow
        )
    }
    .padding()
}
