import Foundation
import NaturalLanguage

/// On-device AI service using Apple's NaturalLanguage framework for summarization,
/// keyword extraction, sentiment analysis, topic classification, entity extraction,
/// and action item detection.
@MainActor
final class AISummaryService: ObservableObject {
    @Published private(set) var isAnalyzing = false
    @Published var errorMessage: String?

    /// All known topic labels for classification.
    static let topicLabels = ["Meeting", "Personal", "Idea", "Tutorial", "News", "Health", "Work", "Other"]

    /// Analyzes a transcription and returns comprehensive AI insights.
    func analyze(transcription: String) async -> AnalysisResult {
        isAnalyzing = true
        errorMessage = nil

        defer { isAnalyzing = false }

        guard !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AnalysisResult(
                summary: "No transcription available to analyze.",
                keywords: [],
                actionItems: [],
                topic: nil,
                sentiment: nil,
                entities: [],
                speakingPace: nil,
                folderSuggestion: nil
            )
        }

        let summary = generateSummary(text: transcription)
        let keywords = extractKeywords(text: transcription)
        let actionItems = extractActionItems(text: transcription)
        let topic = classifyTopic(text: transcription)
        let sentiment = analyzeSentiment(text: transcription)
        let entities = extractEntities(text: transcription)
        let folderSuggestion = suggestFolder(for: topic)

        return AnalysisResult(
            summary: summary,
            keywords: keywords,
            actionItems: actionItems,
            topic: topic,
            sentiment: sentiment,
            entities: entities,
            speakingPace: nil,
            folderSuggestion: folderSuggestion
        )
    }

    /// Analyze with speaking pace (requires audio duration for WPM calculation).
    func analyze(transcription: String, audioDuration: TimeInterval) async -> AnalysisResult {
        var result = await analyze(transcription: transcription)
        let wordCount = countWords(in: transcription)
        let wpm = audioDuration > 0 ? Double(wordCount) / (audioDuration / 60.0) : nil
        return AnalysisResult(
            summary: result.summary,
            keywords: result.keywords,
            actionItems: result.actionItems,
            topic: result.topic,
            sentiment: result.sentiment,
            entities: result.entities,
            speakingPace: wpm,
            folderSuggestion: result.folderSuggestion
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

    // MARK: - Topic Classification

    /// Classifies the transcription into a topic category using keyword matching.
    private func classifyTopic(text: String) -> String? {
        let lowercased = text.lowercased()

        let topicKeywords: [String: [String]] = [
            "Meeting": ["meeting", "agenda", "discuss", "team", "conference", "call", "sync", "standup", "retro", "review", "client", "presentation", "deck", "stakeholder", "roadmap", "sprint", "scrum"],
            "Personal": ["personal", "family", "friend", "home", "weekend", "vacation", "birthday", "holiday", "party", "dinner", "lunch", "coffee", "movie", "book", "hobby"],
            "Idea": ["idea", "concept", "brainstorm", "thought", "wonder", "maybe", "what if", "imagine", "dream", "vision", "creative", "innovation"],
            "Tutorial": ["learn", "tutorial", "how to", "step by step", "guide", "teach", "explain", "example", "demo", "course", "lesson", "workshop"],
            "News": ["news", "update", "announcement", "report", "breaking", "headline", "journalism", "article", "story", "coverage"],
            "Health": ["health", "doctor", "medical", "symptom", "medicine", "exercise", "workout", "gym", "sleep", "diet", "nutrition", "mental health", "therapy", "appointment"],
            "Work": ["deadline", "project", "deliverable", "task", "boss", "colleague", "office", "email", "report", "quarterly", "revenue", "budget", "strategy", "hiring", "interview", "performance"]
        ]

        var bestTopic: String?
        var bestScore = 0

        for (topic, keywords) in topicKeywords {
            let score = keywords.filter { lowercased.contains($0) }.count
            if score > bestScore {
                bestScore = score
                bestTopic = topic
            }
        }

        return bestScore > 0 ? bestTopic : "Other"
    }

    // MARK: - Sentiment Analysis

    /// Analyzes the overall sentiment of the transcription (-1.0 = negative, +1.0 = positive).
    private func analyzeSentiment(text: String) -> Double? {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        var totalScore: Double = 0
        var count = 0

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore, options: [.omitWhitespace]) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                totalScore += score
                count += 1
            }
            return true
        }

        guard count > 0 else { return nil }
        return totalScore / Double(count)
    }

    // MARK: - Entity Extraction

    /// Extracts person names, places, and organizations from the transcription.
    private func extractEntities(text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var entities: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag, tag != .otherWord {
                let entity = String(text[range])
                if entity.count > 2 {
                    entities.append(entity)
                }
            }
            return true
        }

        // Deduplicate and limit
        return Array(Set(entities)).prefix(10).map { $0 }
    }

    // MARK: - Folder Suggestion

    /// Suggests a folder name based on the detected topic.
    private func suggestFolder(for topic: String?) -> String? {
        guard let topic = topic else { return nil }

        let folderMap: [String: String] = [
            "Meeting": "Work Meetings",
            "Personal": "Personal",
            "Idea": "Ideas",
            "Tutorial": "Learning",
            "News": "News & Updates",
            "Health": "Health",
            "Work": "Work",
            "Other": "General"
        ]

        return folderMap[topic]
    }

    // MARK: - Word Count

    private func countWords(in text: String) -> Int {
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = text
        var count = 0
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .tokenType, options: [.omitWhitespace]) { tag, _ in
            if tag == .word { count += 1 }
            return true
        }
        return count
    }
}

// MARK: - Result Types

struct AnalysisResult {
    let summary: String
    let keywords: [String]
    let actionItems: [String]
    var topic: String?
    var sentiment: Double?
    var entities: [String]
    var speakingPace: Double? // words per minute
    var folderSuggestion: String?
}
