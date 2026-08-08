import SwiftUI
import SwiftData

struct VoiceEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingTasks: [PlannerTask]

    @StateObject private var recognizer = SpeechRecognizer()
    @State private var phase: Phase = .requestingPermission
    @State private var editedTitle = ""
    @State private var selectedHour = GridConfig.startHour
    @State private var errorMessage: String?

    private enum Phase {
        case requestingPermission
        case recording
        case reviewing
        case unavailable
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .requestingPermission:
                    ProgressView("Requesting access…")
                case .unavailable:
                    ContentUnavailableView(
                        "Microphone Access Needed",
                        systemImage: "mic.slash",
                        description: Text(errorMessage ?? "Enable microphone and speech recognition access in Settings to use voice entry.")
                    )
                case .recording:
                    recordingContent
                case .reviewing:
                    reviewContent
                }
            }
            .padding()
            .navigationTitle("Add by Voice")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recognizer.stopRecording()
                        dismiss()
                    }
                }
            }
        }
        .task { await beginFlow() }
    }

    private var recordingContent: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(.red)
                .symbolEffect(.variableColor.iterative, isActive: recognizer.isRecording)
            Text(recognizer.transcript.isEmpty ? "Listening…" : recognizer.transcript)
                .multilineTextAlignment(.center)
                .foregroundStyle(recognizer.transcript.isEmpty ? .secondary : .primary)
                .padding(.horizontal)
            Spacer()
            Button("Done", action: finishRecording)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private var reviewContent: some View {
        Form {
            Section("Task") {
                TextField("Title", text: $editedTitle)
            }
            Section("Hour") {
                Picker("Hour", selection: $selectedHour) {
                    ForEach(GridConfig.startHour..<GridConfig.endHour, id: \.self) { h in
                        Text(GridConfig.hourLabel(h)).tag(h)
                    }
                }
            }
            Section {
                Button("Create Task", action: createTask)
                    .disabled(editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func beginFlow() async {
        let granted = await recognizer.requestAuthorization()
        guard granted else {
            phase = .unavailable
            return
        }
        do {
            try recognizer.startRecording()
            phase = .recording
        } catch {
            errorMessage = error.localizedDescription
            phase = .unavailable
        }
    }

    private func finishRecording() {
        recognizer.stopRecording()
        let parsed = SpokenTaskParser.parse(recognizer.transcript)
        editedTitle = parsed.title
        selectedHour = parsed.hour ?? GridConfig.nextOpenHour(for: existingTasks)
        phase = .reviewing
    }

    private func createTask() {
        let title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTask = PlannerTask(
            title: title,
            scheduledDate: Calendar.current.startOfDay(for: Date()),
            startHour: selectedHour
        )
        modelContext.insert(newTask)
        NotificationScheduler.reschedule(for: newTask)
        dismiss()
    }
}
