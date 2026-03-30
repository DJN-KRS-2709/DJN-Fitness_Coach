import Foundation

// MARK: - RAG Chunk Model

struct RAGChunk: Decodable {
    let chunkId: String
    let sourceName: String
    let creatorName: String?
    let sourceType: String
    let topicTags: [String]
    let claimType: String
    let evidenceScore: Int
    let creatorTrustScore: Int
    let summary: String
    let canonicalClaim: String
    let evidenceGrade: String

    enum CodingKeys: String, CodingKey {
        case chunkId = "chunk_id"
        case sourceName = "source_name"
        case creatorName = "creator_name"
        case sourceType = "source_type"
        case topicTags = "topic_tags"
        case claimType = "claim_type"
        case evidenceScore = "evidence_score"
        case creatorTrustScore = "creator_trust_score"
        case summary
        case canonicalClaim = "canonical_claim"
        case evidenceGrade = "evidence_grade"
    }
}

private struct RAGStore: Decodable {
    let chunks: [RAGChunk]
}

// MARK: - RAG Service

final class RAGService {
    static let shared = RAGService()

    private var chunks: [RAGChunk] = []

    private init() {
        load()
    }

    // MARK: - Load

    private func load() {
        guard let url = Bundle.main.url(forResource: "rag_knowledge", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(RAGStore.self, from: data)
        else { return }
        chunks = store.chunks
    }

    // MARK: - Search

    /// Returns top-k chunks most relevant to the query, formatted as a context block.
    func retrieve(query: String, topK: Int = 4) -> [RAGChunk] {
        guard !chunks.isEmpty else { return [] }
        let tokens = tokenize(query)
        guard !tokens.isEmpty else { return [] }

        let scored = chunks.map { chunk -> (RAGChunk, Double) in
            let score = relevanceScore(tokens: tokens, chunk: chunk)
            return (chunk, score)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }

        return Array(scored.prefix(topK).map { $0.0 })
    }

    /// Formats retrieved chunks as a context block to inject into the system prompt.
    func buildContext(for query: String, topK: Int = 4) -> String? {
        let results = retrieve(query: query, topK: topK)
        guard !results.isEmpty else { return nil }

        var lines = ["## KNOWLEDGE BASE CONTEXT (from RAG)\n"]
        for (i, chunk) in results.enumerated() {
            let creator = chunk.creatorName.map { " (\($0))" } ?? ""
            lines.append("[\(i + 1)] \(chunk.sourceName)\(creator) — Evidence grade: \(chunk.evidenceGrade.uppercased()) (score: \(chunk.evidenceScore)/5)")
            lines.append("Claim: \(chunk.canonicalClaim)")
            lines.append("Detail: \(chunk.summary)\n")
        }
        lines.append("Use the above knowledge to inform your answer. Always cite evidence grade when relevant.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Scoring

    private func relevanceScore(tokens: [String], chunk: RAGChunk) -> Double {
        let searchText = ([
            chunk.canonicalClaim,
            chunk.summary,
            chunk.topicTags.joined(separator: " "),
            chunk.claimType,
            chunk.sourceName,
            chunk.creatorName ?? ""
        ]).joined(separator: " ").lowercased()

        var score = 0.0
        for token in tokens {
            if searchText.contains(token) {
                // Weight longer tokens more (more specific)
                score += Double(token.count) * 0.1
                // Bonus if token appears in canonical claim
                if chunk.canonicalClaim.lowercased().contains(token) { score += 0.5 }
                // Bonus if token appears in topic tags
                if chunk.topicTags.joined().lowercased().contains(token) { score += 0.4 }
            }
        }
        // Boost by evidence quality
        score *= (1.0 + Double(chunk.evidenceScore) * 0.1)
        return score
    }

    private func tokenize(_ text: String) -> [String] {
        let stopWords: Set<String> = [
            "i", "me", "my", "the", "a", "an", "is", "are", "was", "were",
            "be", "been", "being", "have", "has", "had", "do", "does", "did",
            "will", "would", "could", "should", "may", "might", "shall",
            "to", "of", "in", "for", "on", "with", "at", "by", "from",
            "it", "its", "this", "that", "these", "those", "and", "or",
            "but", "if", "so", "as", "what", "how", "when", "why", "where",
            "can", "not", "no", "yes", "about", "any", "some", "also",
            "just", "more", "very", "too", "now", "then"
        ]
        return text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) }
    }
}
