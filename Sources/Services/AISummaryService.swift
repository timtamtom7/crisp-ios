import Foundation
import NaturalLanguage

/// On-device AI service using Apple's NaturalLanguage framework for summarization,
/// keyword extraction, and action item detection.
@MainActor
final class AISummaryService: ObservableObject {
    @Published private(set) var isAnalyzing = false
    @Published var errorMessage: String?

    /// Analyzes a transcription and returns a summary with keywords and action items.
    func analyze(transcription: String) async -> AnalysisResult {
        isAnalyzing = true
        errorMessage = nil

        defer { isAnalyzing = false }

        guard !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AnalysisResult(
                summary: "No transcription available to analyze.",
                keywords: [],
                actionItems: []
            )
        }

        let summary = generateSummary(text: transcription)
        let keywords = extractKeywords(text: transcription)
        let actionItems = extractActionItems(text: transcription)

        return AnalysisResult(
            summary: summary,
            keywords: keywords,
            actionItems: actionItems
        )
    }

    // MARK: - Summarization

    private func generateSummary(text: String) -> String {
        // Use extractive summarization: score sentences by importance and combine top ones.
        let sentences = splitIntoSentences(text)
        guard sentences.count > 1 else {
            return text.prefix(280) + (text.count > 280 ? "..." : "")
        }

        // Score sentences using TF-IDF-like approach (word frequency)
        let wordScores = computeWordScores(sentences: sentences)
        let scoredSentences = sentences.enumerated().map { (index, sentence) -> (Int, String, Double) in
            let score = sentenceScore(sentence, wordScores: wordScores, positionBonus: Double(sentences.count - index))
            return (index, sentence, score)
        }

        // Take top sentences up to ~3, preserving original order
        let topSentences = scoredSentences
            .sorted { $0.2 > $1.2 }
            .prefix(3)
            .map { $0.0 }
            .sorted()
            .map { sentences[$0] }

        let summary = topSentences.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? text.prefix(280) + (text.count > 280 ? "..." : "") : summary
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]))
            return true
        }
        return sentences
    }

    private func computeWordScores(sentences: [String]) -> [String: Double] {
        var docFreq: [String: Int] = [:]
        var wordInDoc: [String: Int] = [:]

        for sentence in sentences {
            let words = extractWords(sentence)
            let uniqueWords = Set(words.map { $0.lowercased() })
            for word in uniqueWords {
                docFreq[word, default: 0] += 1
            }
            for word in words.map({ $0.lowercased() }) {
                wordInDoc[word, default: 0] += 1
            }
        }

        var scores: [String: Double] = [:]
        for (word, count) in wordInDoc {
            // IDF-like score
            let idf = log(Double(sentences.count) / Double(max(docFreq[word] ?? 1, 1)))
            scores[word] = Double(count) * idf
        }
        return scores
    }

    private func sentenceScore(_ sentence: String, wordScores: [String: Double], positionBonus: Double) -> Double {
        let words = extractWords(sentence)
        let wordScore = words.map { wordScores[$0.lowercased()] ?? 0 }.reduce(0, +)
        return wordScore + positionBonus * 0.5
    }

    // MARK: - Keyword Extraction

    private func extractKeywords(text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        var wordFreq: [String: Int] = [:]
        let stopWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "is", "was", "are", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "can", "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they", "what", "which", "who", "when", "where", "why", "how", "all", "each", "every", "both", "few", "more", "most", "other", "some", "such", "no", "nor", "not", "only", "own", "same", "so", "than", "too", "very", "just", "also", "now", "here", "there", "then", "once", "if", "about", "into", "through", "during", "before", "after", "above", "below", "between", "under", "again", "further", "from", "up", "down", "out", "off", "over", "any", "anyway"])

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            if let tag = tag, [.noun, .verb, .adjective].contains(tag) {
                let word = String(text[range]).lowercased()
                if word.count > 3 && !stopWords.contains(word) {
                    wordFreq[word, default: 0] += 1
                }
            }
            return true
        }

        return wordFreq
            .sorted { $0.value > $1.value }
            .prefix(8)
            .map { $0.key.capitalized }
    }

    // MARK: - Action Item Detection

    private func extractActionItems(text: String) -> [String] {
        let sentences = splitIntoSentences(text)
        var actionItems: [String] = []

        let actionPatterns = [
            "need to", "needs to", "have to", "has to", "must", "should", "ought to",
            "will", "going to", "plan to", "remember to", "don't forget to",
            "please", "remind me", "task", "todo", "to-do", "action item",
            "assign", "follow up", "follow-up", "send", "call", "email", "create",
            "buy", "get", "make", "do", "finish", "complete", "submit", "schedule",
            "organize", "prepare", "review", "check", "look into", "figure out"
        ]

        let imperativePatterns = ["call", "email", "send", "remind", "check", "buy", "get", "schedule", "prepare", "review", "submit", "finish", "complete", "do", "make", "organize", "create", "book", "confirm", "arrange", "pick up", "set up", "look into", "find", "order"]

        for sentence in sentences {
            let lowercased = sentence.lowercased()

            // Pattern-based detection
            if actionPatterns.contains(where: { lowercased.contains($0) }) {
                let cleaned = sentence.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\n\t "))
                if cleaned.count > 10 && cleaned.count < 200 {
                    actionItems.append(cleaned)
                    continue
                }
            }

            // Imperative mood detection (sentence starting with verb)
            let firstWord = lowercased.split(separator: " ").first.map(String.init) ?? ""
            if imperativePatterns.contains(firstWord) && !lowercased.contains("?") {
                let cleaned = sentence.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:\n\t "))
                if cleaned.count > 5 && cleaned.count < 200 {
                    actionItems.append(cleaned)
                }
            }
        }

        return Array(actionItems.prefix(5))
    }

    // MARK: - Helpers

    private func extractWords(_ text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var words: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            if let tag = tag, [.noun, .verb, .adjective].contains(tag) {
                words.append(String(text[range]))
            }
            return true
        }
        return words
    }
}

// MARK: - Result Types

struct AnalysisResult {
    let summary: String
    let keywords: [String]
    let actionItems: [String]
}
