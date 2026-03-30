import SwiftUI
import SwiftData
import PhotosUI

struct CoachView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speech = SpeechRecognizer()

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var streamingText = ""
    @State private var showAPISetup = false
    @State private var apiKey = AnthropicService.shared.apiKey
    @State private var hasKey = AnthropicService.shared.hasApiKey
    @State private var dataService: DataService?

    // Vision attachments
    @State private var attachedImages: [UIImage] = []
    @State private var photoPickerItems: [PhotosPickerItem] = []

    // Allows external handoff (e.g. from Progress tab "Send to Coach")
    var pendingImage: UIImage? = nil

    private let welcomeMessage = ChatMessage(
        role: "assistant",
        content: "Hey. I'm your coach — I know your full profile, today's recovery state, sessions, and nutrition. What do you need?\n\nYou can also attach a body photo and I'll evaluate your physique, body composition, and areas to focus on."
    )

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if !hasKey {
                    noKeyView
                } else {
                    chatView
                }
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAPISetup = true } label: {
                        Image(systemName: "key.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showAPISetup) {
                APIKeySetupView(apiKey: $apiKey)
                    .onDisappear {
                        apiKey = AnthropicService.shared.apiKey
                        hasKey = AnthropicService.shared.hasApiKey
                    }
            }
        }
        .onAppear {
            let ds = DataService(modelContext: modelContext)
            dataService = ds
            if messages.isEmpty {
                messages = [welcomeMessage]
            }
            // Accept image handed off from Progress tab
            if let img = pendingImage {
                attachedImages.append(img)
                inputText = "Please evaluate my physique in this photo — body composition, muscle development, visible body fat, and priority areas for improvement."
            }
        }
        .onChange(of: photoPickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run { attachedImages.append(img) }
                    }
                }
                await MainActor.run { photoPickerItems = [] }
            }
        }
    }

    // MARK: - No Key State

    private var noKeyView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColors.purple.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44))
                    .foregroundColor(AppColors.purple)
            }
            VStack(spacing: 8) {
                Text("Coach Not Configured")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                Text("Add your OpenAI API key to start chatting with your AI coach.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button { showAPISetup = true } label: {
                Label("Add API Key", systemImage: "key.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(AppColors.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
            Spacer()
        }
    }

    // MARK: - Chat View

    private var chatView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                        if isStreaming && !streamingText.isEmpty {
                            streamingBubble.id("streaming")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
                .onChange(of: streamingText) { _, _ in scrollToBottom(proxy) }
            }

            inputBar
        }
    }

    private var streamingBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(AppColors.purple.opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.purple)
            }
            Text(streamingText.isEmpty ? "..." : streamingText)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textPrimary)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppColors.cardBorder, lineWidth: 0.5))
            Spacer(minLength: 48)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(AppColors.cardBorder)

            // Attached image thumbnails
            if !attachedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(attachedImages.enumerated()), id: \.offset) { idx, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button {
                                    attachedImages.remove(at: idx)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(AppColors.background)
            }

            HStack(spacing: 10) {
                voiceButton

                TextField("Ask your coach...", text: $inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(AppColors.cardBorder, lineWidth: 0.5))

                attachPhotoButton
                sendButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.background)
        }
    }

    private var voiceButton: some View {
        Button {
            Task { await toggleVoice() }
        } label: {
            ZStack {
                Circle()
                    .fill(speech.isRecording ? AppColors.red.opacity(0.2) : AppColors.cardBackground)
                    .frame(width: 38, height: 38)
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 15))
                    .foregroundColor(speech.isRecording ? AppColors.red : AppColors.textSecondary)
            }
        }
        .onChange(of: speech.transcript) { _, newValue in
            if !newValue.isEmpty { inputText = newValue }
        }
    }

    private var attachPhotoButton: some View {
        PhotosPicker(selection: $photoPickerItems, maxSelectionCount: 4, matching: .images) {
            ZStack {
                Circle()
                    .fill(attachedImages.isEmpty ? AppColors.cardBackground : AppColors.purple.opacity(0.2))
                    .frame(width: 38, height: 38)
                Image(systemName: "photo")
                    .font(.system(size: 15))
                    .foregroundColor(attachedImages.isEmpty ? AppColors.textSecondary : AppColors.purple)
            }
        }
    }

    private var sendButton: some View {
        Button { sendMessage() } label: {
            ZStack {
                Circle()
                    .fill(canSend ? AppColors.purple : AppColors.cardBackground)
                    .frame(width: 38, height: 38)
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(canSend ? .black : AppColors.textSecondary)
            }
        }
        .disabled(!canSend)
    }

    private var canSend: Bool {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || !attachedImages.isEmpty) && !isStreaming
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isStreaming, !text.isEmpty || !attachedImages.isEmpty else { return }

        if speech.isRecording { speech.stopRecording() }

        let userMsg = ChatMessage(role: "user", content: text, images: attachedImages)
        messages.append(userMsg)
        inputText = ""
        attachedImages = []
        streamingText = ""
        isStreaming = true

        let systemPrompt = buildSystemPrompt(for: text)
        let history = messages

        Task {
            do {
                for try await chunk in AnthropicService.shared.streamResponse(
                    messages: history,
                    systemPrompt: systemPrompt
                ) {
                    await MainActor.run { streamingText += chunk }
                }
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: streamingText))
                    streamingText = ""
                    isStreaming = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: "Sorry, something went wrong: \(error.localizedDescription)"))
                    streamingText = ""
                    isStreaming = false
                }
            }
        }
    }

    private func toggleVoice() async {
        if speech.isRecording {
            speech.stopRecording()
        } else {
            if await speech.requestPermissions() {
                speech.startRecording()
            }
        }
    }

    private func buildSystemPrompt(for userMessage: String) -> String {
        let ragContext = RAGService.shared.buildContext(for: userMessage, topK: 4)
        guard let ds = dataService else {
            return AnthropicService.shared.buildSystemPrompt(todayLog: nil, weeklyCounters: RuleEngine.WeeklyCounters(), ragContext: ragContext)
        }
        let todayLog = ds.fetchOrCreateTodayLog()
        let weekLogs = ds.fetchLogsForCurrentWeek()
        let counters = RuleEngine.buildWeeklyCounters(from: weekLogs)
        let health = HealthKitService.shared.isAuthorized ? HealthKitService.shared.snapshot : nil
        return AnthropicService.shared.buildSystemPrompt(todayLog: todayLog, weeklyCounters: counters, health: health, ragContext: ragContext)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isStreaming {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 48)
                VStack(alignment: .trailing, spacing: 6) {
                    // Attached images
                    if !message.images.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(message.images.enumerated()), id: \.offset) { _, img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                            .textSelection(.enabled)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppColors.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            } else {
                ZStack {
                    Circle()
                        .fill(AppColors.purple.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.purple)
                }
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppColors.cardBorder, lineWidth: 0.5))
                Spacer(minLength: 48)
            }
        }
    }
}
