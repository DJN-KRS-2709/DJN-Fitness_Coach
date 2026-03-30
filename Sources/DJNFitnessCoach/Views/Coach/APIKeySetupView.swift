import SwiftUI

struct APIKeySetupView: View {
    @Binding var apiKey: String
    @Environment(\.dismiss) private var dismiss
    @State private var inputKey = ""
    @State private var isSecure = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppColors.purple.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 36))
                                .foregroundColor(AppColors.purple)
                        }

                        Text("Connect Your Coach")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)

                        Text("Enter your OpenAI API key to activate the AI coach. Your key is stored only on this device.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OPENAI API KEY")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .tracking(0.8)

                            HStack {
                                Group {
                                    if isSecure {
                                        SecureField("sk-proj-...", text: $inputKey)
                                            .focused($isFocused)
                                    } else {
                                        TextField("sk-proj-...", text: $inputKey)
                                            .focused($isFocused)
                                    }
                                }
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(AppColors.textPrimary)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .textContentType(.password)
                                .submitLabel(.done)
                                .onSubmit {
                                    let trimmed = inputKey.trimmingCharacters(in: .whitespaces)
                                    guard !trimmed.isEmpty else { return }
                                    apiKey = trimmed
                                    AnthropicService.shared.apiKey = trimmed
                                    dismiss()
                                }

                                // Paste from clipboard button
                                Button {
                                    if let clip = UIPasteboard.general.string {
                                        inputKey = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 15))
                                        .foregroundColor(AppColors.purple)
                                }

                                Button {
                                    isSecure.toggle()
                                } label: {
                                    Image(systemName: isSecure ? "eye.slash" : "eye")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            .padding(12)
                            .background(AppColors.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isFocused ? AppColors.purple : Color.clear, lineWidth: 1.5))

                            Text("Get your key at platform.openai.com/api-keys")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)

                    Button {
                        let trimmed = inputKey.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        apiKey = trimmed
                        AnthropicService.shared.apiKey = trimmed
                        dismiss()
                    } label: {
                        Text("Activate Coach")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(inputKey.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.purple.opacity(0.4) : AppColors.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(inputKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 20)

                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("API Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !apiKey.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .onAppear {
                inputKey = apiKey
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
        }
    }
}
