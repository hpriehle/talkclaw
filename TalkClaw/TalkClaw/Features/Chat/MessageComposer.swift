import SwiftUI
import AVFoundation

struct MessageComposer: View {
    @Binding var text: String
    @Binding var attachments: [AttachmentItem]
    let isDisabled: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool
    @State private var inputHeight: CGFloat = PastableTextView.minHeight
    @State private var mode: ComposerMode = .idle
    @State private var audioManager = AudioRecorderManager()
    @State private var showPermissionAlert = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false

    enum ComposerMode: Equatable {
        case idle
        case typing
        case recording
        case transcribing
    }

    private var effectiveMode: ComposerMode {
        if mode == .recording || mode == .transcribing { return mode }
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachments = !attachments.isEmpty
        return (hasText || hasAttachments) ? .typing : .idle
    }

    var body: some View {
        VStack(spacing: 0) {
            // Attachment preview strip
            if !attachments.isEmpty && effectiveMode != .recording {
                AttachmentPreviewStrip(attachments: attachments) { item in
                    attachments.removeAll { $0.id == item.id }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
                // Attachment button (hidden during recording/transcribing)
                if effectiveMode == .idle || effectiveMode == .typing {
                    attachmentButton
                }

                // Center: text field, recording overlay, or transcribing indicator
                Group {
                    switch effectiveMode {
                    case .recording:
                        VoiceRecordingOverlay(
                            audioManager: audioManager,
                            onCancel: { cancelRecording() }
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8, anchor: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))

                    case .transcribing:
                        HStack(spacing: Theme.Spacing.sm) {
                            ProgressView()
                                .tint(Theme.Colors.accent)
                            Text("Transcribing...")
                                .font(Theme.Typography.subhead)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.md)
                        .glassCard(cornerRadius: Theme.Radius.xl)
                        .transition(.opacity)

                    case .idle, .typing:
                        textFieldView
                            .transition(.opacity)
                    }
                }

                // Right side: send button, mic button, or nothing
                Group {
                    switch effectiveMode {
                    case .typing:
                        sendButton
                            .transition(.scale.combined(with: .opacity))
                    case .idle, .recording:
                        voiceButton
                            .transition(.scale.combined(with: .opacity))
                    case .transcribing:
                        EmptyView()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xs)
        }
        .background(Theme.Colors.background)
        .animation(Theme.Anim.spring, value: effectiveMode)
        .animation(Theme.Anim.smooth, value: attachments.isEmpty)
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable microphone and speech recognition in Settings to use voice input.")
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView { items in
                attachments.append(contentsOf: items)
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { items in
                attachments.append(contentsOf: items)
            }
        }
    }

    // MARK: - Attachment Button

    private var attachmentButton: some View {
        Menu {
            Button {
                showPhotoPicker = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }
            Button {
                showDocumentPicker = true
            } label: {
                Label("Files", systemImage: "folder")
            }
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 36, height: 36)
        }
    }

    // MARK: - Text Field

    private var textFieldView: some View {
        PastableTextView(
            text: $text,
            isFocused: isFocused,
            placeholder: "Message",
            onImagePaste: { data, mimeType in
                let filename = "pasted_\(UUID().uuidString.prefix(8)).jpg"
                let thumbnail = UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 120, height: 120))
                attachments.append(AttachmentItem(
                    data: data,
                    filename: filename,
                    mimeType: mimeType,
                    thumbnail: thumbnail
                ))
            },
            onHeightChange: { newHeight in
                inputHeight = newHeight
            }
        )
        .frame(height: inputHeight)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .interactiveGlass(in: RoundedRectangle(cornerRadius: Theme.Radius.xl))
        .animation(Theme.Anim.fast, value: inputHeight)
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(canSend ? .white : Theme.Colors.textDisabled)
                .frame(width: 36, height: 36)
                .background(canSend ? Theme.Colors.accent : .clear, in: Circle())
                .liquidGlass(in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canSend)
    }

    // MARK: - Voice Button

    private var voiceButton: some View {
        Image(systemName: mode == .recording ? "mic.fill" : "mic")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(mode == .recording ? .white : Theme.Colors.accent)
            .frame(width: 36, height: 36)
            .background(mode == .recording ? Theme.Colors.error : .clear, in: Circle())
            .liquidGlass(in: Circle())
            .animation(Theme.Anim.smooth, value: mode == .recording)
            .gesture(
                LongPressGesture(minimumDuration: 0.2)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .second(true, _):
                            if mode != .recording {
                                startRecording()
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { _ in
                        if mode == .recording {
                            stopAndTranscribe()
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            )
    }

    // MARK: - Recording Logic

    private func startRecording() {
        Task {
            let micGranted = await AVAudioApplication.requestRecordPermission()
            let speechGranted = await SpeechRecognitionService.requestAuthorization()

            guard micGranted && speechGranted else {
                showPermissionAlert = true
                return
            }

            do {
                try audioManager.startRecording()
                mode = .recording
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
    }

    private func cancelRecording() {
        audioManager.cancelRecording()
        mode = .idle
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.impactOccurred()
    }

    private func stopAndTranscribe() {
        guard let fileURL = audioManager.stopRecording() else {
            mode = .idle
            return
        }

        mode = .transcribing

        Task {
            do {
                let transcription = try await SpeechRecognitionService.transcribe(fileURL: fileURL)
                text = transcription
                isFocused = true
            } catch {
                print("Transcription failed: \(error)")
            }
            mode = .idle
            audioManager.cleanup()
        }
    }

    private var canSend: Bool {
        guard !isDisabled else { return false }
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAttachments = !attachments.isEmpty
        return hasText || hasAttachments
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(Theme.Anim.fast, value: configuration.isPressed)
    }
}
