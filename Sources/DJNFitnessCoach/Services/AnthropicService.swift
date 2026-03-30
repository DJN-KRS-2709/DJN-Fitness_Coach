import Foundation
import SwiftData
import UIKit

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String   // "user" or "assistant"
    var content: String
    var images: [UIImage]   // vision images attached to this message
    let timestamp: Date

    init(role: String, content: String, images: [UIImage] = []) {
        self.role = role
        self.content = content
        self.images = images
        self.timestamp = Date()
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AI Service (OpenAI)

class AnthropicService {
    static let shared = AnthropicService()
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o"

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "djn_ai_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "djn_ai_api_key") }
    }

    var hasApiKey: Bool { !apiKey.isEmpty }

    // MARK: - System Prompt Builder

    func buildSystemPrompt(todayLog: DailyLog?, weeklyCounters: RuleEngine.WeeklyCounters, health: HealthSnapshot? = nil, ragContext: String? = nil) -> String {
        let recovery = todayLog?.recovery
        let nutrition = todayLog?.nutrition
        let workout = todayLog?.workout
        let cardio = todayLog?.cardio

        let recoveryState = recovery?.recoveryState.rawValue ?? "unknown"
        let sessionType = todayLog?.sessionType?.rawValue ?? "not yet determined"

        var prompt = """
        You are the personal fitness coach for DJN — a highly advanced, evidence-based AI coach built exclusively for this athlete. You know everything about them. Be direct, precise, and concise. No fluff. No disclaimers. You speak like a seasoned strength coach who also understands longevity science.

        ## ATHLETE PROFILE

        - Age: 43 | Male | 181 cm | ~80 kg | ~8–11% body fat
        - Training age: 25–27 years (advanced)
        - Goals: Longevity, cardiovascular fitness, maintain muscle mass and performance
        - Eating style: Intermittent fasting — first meal ~12:00, trains fasted/semi-fasted in the morning
        - Post-workout meal delay: ~2.5 hours

        ## TRAINING STRUCTURE

        - Full body lifting every second day
        - Cardio on non-lifting days
        - Lifting: Chest 4 sets, Back 4 sets, Shoulders 2 sets, Arms 2 sets, Legs 2–3 sets
        - Intensity: High effort, mostly to failure
        - Cardio: VO2 Max running (primary, 1–2×/week), Norwegian 4×4 (max 1×/week), Zone 2 (~1×/week)
        - Cardio duration: ~45 min

        ## NUTRITION TARGETS

        - Calories: 2800–3200 kcal
        - Protein: 200–230g | Carbs: 270–320g | Fat: 70–90g
        - Sodium: 2–3g/day (Himalayan salt in workout drink)
        - Core daily foods: 500g low fat quark, ~50g whey, ~40g clear whey, ~50g casein, 200g beef/chicken, 2–3 eggs, ~200g rice (dry), fruit, Medjool dates, 20g dark chocolate, walnuts, Brazil nuts, parmesan, 300–400g vegetables, 3–4 flat whites with oat milk

        ## SUPPLEMENT STACK

        Daily: Omega-3 (360mg EPA/240mg DHA), Magnesium glycinate 150mg, Glycine 2g, NAD+ 1000mg, Ashwagandha 2400mg, Urolithin A 2000mg, Vitamin D3+K2 2000IU, Zinc bisglycinate 225mg, Boron 4mg, Creatine 10–15g, Glutamine 5g, Whey 50g, Clear whey 40g, Casein 50g
        Every second day: Methylene blue 10ml, Cumin oil 2–3mg

        ## RECOVERY BASELINE (normal state)

        Sleep: good | Libido: good | Energy: good | No overtraining symptoms

        ## RULE ENGINE SUMMARY

        - High recovery → proceed as planned, high intensity allowed
        - Moderate recovery → reduce volume ~15%, no failure sets, consider Zone 2 over VO2
        - Low recovery → -30% volume, no failure sets, block high intensity cardio
        - If 2+ high intensity cardio sessions done this week → next must be Zone 2
        - Norwegian 4×4 max once per week
        - If strength declines 2 consecutive sessions AND high cardio load → reduce VO2 frequency

        ---

        ## TODAY'S LIVE DATA (\(formattedDate()))

        - Today's session: \(sessionType)
        - Recovery state: \(recoveryState)
        """

        if let rec = recovery {
            prompt += """

        - Sleep: \(String(format: "%.1f", rec.sleepHours))h | Quality: \(rec.sleepQuality)/5
        - Energy: \(rec.energyScore)/5 | Motivation: \(rec.motivationScore)/5
        - Soreness: \(rec.sorenessScore)/5 | Stress: \(rec.stressScore)/5
        - Libido: \(rec.libidoStatus.rawValue)
        - Perceived recovery: \(rec.perceivedRecoveryScore)/10
        """
            if let rhr = rec.restingHeartRate {
                prompt += "\n        - Resting HR: \(rhr) bpm"
            }
        } else {
            prompt += "\n        - Recovery: not yet logged today"
        }

        if let w = workout, w.completed {
            prompt += "\n        - Lifting: DONE — \(w.totalSets) sets, \(w.durationMinutes) min, RPE \(w.perceivedExertion)/10"
        }
        if let c = cardio, c.completed {
            prompt += "\n        - Cardio: DONE — \(c.type.rawValue), \(c.durationMinutes) min"
        }

        if let n = nutrition {
            prompt += """

        - Nutrition logged: \(Int(n.proteinG))g protein | \(Int(n.carbsG))g carbs | \(Int(n.fatG))g fat | \(n.calories) kcal
        """
        } else {
            prompt += "\n        - Nutrition: not yet logged today"
        }

        prompt += """

        - This week: \(weeklyCounters.liftingDone) lifts | \(weeklyCounters.vo2Done) VO2 | \(weeklyCounters.norwegianDone) Norwegian 4×4 | \(weeklyCounters.zone2Done) Zone 2
        """

        if let h = health, h.isAvailable {
            prompt += "\n\n        ## APPLE HEALTH DATA (today)"
            if let rhr = h.restingHR { prompt += "\n        - Resting HR: \(Int(rhr)) bpm" }
            if let hrv = h.hrv { prompt += "\n        - HRV (SDNN): \(Int(hrv)) ms" }
            if let sl = h.sleepHours { prompt += String(format: "\n        - Sleep (Watch): %.1fh", sl) }
            if let st = h.steps { prompt += "\n        - Steps: \(st)" }
            if let cal = h.activeCalories { prompt += "\n        - Active calories: \(cal) kcal" }
            if let w = h.bodyWeight { prompt += String(format: "\n        - Body weight: %.1f kg", w) }
            if let bf = h.bodyFat { prompt += String(format: "\n        - Body fat: %.1f%%", bf) }
            if let v = h.vo2Max { prompt += String(format: "\n        - VO2 max: %.1f mL/kg/min", v) }
        }

        if let rag = ragContext {
            prompt += "\n\n" + rag
        }

        prompt += """


        ---

        Respond conversationally but concisely. Lead with the answer. Use the athlete's current data when relevant. When knowledge base context is provided, use it to ground your answer and cite evidence grade. Never ask for information you already have.
        """

        return prompt
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: Date())
    }

    /// Encodes a ChatMessage to the OpenAI message dict, supporting vision (image_url content).
    private func encodeMessage(_ msg: ChatMessage) -> [String: Any] {
        if msg.images.isEmpty {
            return ["role": msg.role, "content": msg.content]
        }
        // Vision message: content is an array of content parts
        var parts: [[String: Any]] = []
        for image in msg.images {
            if let jpeg = image.jpegData(compressionQuality: 0.8) {
                let b64 = jpeg.base64EncodedString()
                parts.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(b64)", "detail": "high"]
                ])
            }
        }
        if !msg.content.isEmpty {
            parts.append(["type": "text", "text": msg.content])
        }
        return ["role": msg.role, "content": parts]
    }

    // MARK: - Streaming API Call (OpenAI)

    func streamResponse(
        messages: [ChatMessage],
        systemPrompt: String
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = URLRequest(url: self.endpoint)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    var messagePayload: [[String: Any]] = [
                        ["role": "system", "content": systemPrompt]
                    ]
                    messagePayload += messages.map { self.encodeMessage($0) }

                    let body: [String: Any] = [
                        "model": self.model,
                        "max_tokens": 1024,
                        "stream": true,
                        "messages": messagePayload
                    ]

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await byte in bytes {
                            errorBody += String(bytes: [byte], encoding: .utf8) ?? ""
                        }
                        throw AnthropicError.apiError(httpResponse.statusCode, errorBody)
                    }

                    var lineBuffer = ""
                    for try await byte in bytes {
                        let char = String(bytes: [byte], encoding: .utf8) ?? ""
                        lineBuffer += char

                        while let newlineRange = lineBuffer.range(of: "\n") {
                            let line = String(lineBuffer[..<newlineRange.lowerBound])
                            lineBuffer = String(lineBuffer[newlineRange.upperBound...])

                            if line.hasPrefix("data: ") {
                                let data = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                                if data == "[DONE]" {
                                    continuation.finish()
                                    return
                                }
                                if let jsonData = data.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                   let choices = json["choices"] as? [[String: Any]],
                                   let delta = choices.first?["delta"] as? [String: Any],
                                   let text = delta["content"] as? String {
                                    continuation.yield(text)
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

enum AnthropicError: LocalizedError {
    case noApiKey
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "No API key configured. Add your Anthropic API key in Coach settings."
        case .apiError(let code, let body):
            return "API error \(code): \(body.prefix(200))"
        }
    }
}
