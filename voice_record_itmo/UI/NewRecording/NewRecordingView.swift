//
//  NewRecordingView.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

struct NewRecordingView: View {
    @StateObject var viewModel: NewRecordingViewModel
    
    @Environment(\.dismiss) private var dismiss

    @State private var elapsedSeconds: Int = 42
    @State private var isPaused: Bool = false
    @State private var isBookmarked: Bool = false
    @State private var recordingName: String = ""

    @State private var pulse: Bool = false
    @State private var timer: Timer?

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        titleRow

                        micPulse

                        timeBlock

                        nameCard

                        controlRow

                        Spacer(minLength: 12)

                        finishButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startPulse()
            startTimerIfNeeded()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Top status bar

    // MARK: - Title row

    private var titleRow: some View {
        ZStack {
            Text("New Recording")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(.label))

            HStack {
                CircleIconButton(systemImage: "xmark") {
                    dismiss()
                }
                Spacer()
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Mic pulse

    private var micPulse: some View {
        ZStack {
            Circle()
                .fill(Color(.systemIndigo).opacity(pulse ? 0.18 : 0.12))
                .frame(width: 240, height: 240)
                .scaleEffect(pulse ? 1.08 : 0.92)

            Circle()
                .fill(Color(.systemPurple).opacity(pulse ? 0.22 : 0.16))
                .frame(width: 200, height: 200)
                .scaleEffect(pulse ? 1.05 : 0.95)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(.systemIndigo), Color(.systemPurple)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 150)
                .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 10)

            Image(systemName: "mic.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.top, 4)
    }

    // MARK: - Time block

    private var timeBlock: some View {
        VStack(spacing: 8) {
            Text(formatTime(elapsedSeconds))
                .font(.system(size: 62, weight: .black))
                .foregroundStyle(Color(.label))

            Text(isPaused ? "Recording paused..." : "Recording in progress...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    // MARK: - Name card

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recording Name")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(.label))

            TextField("Enter recording name...", text: $recordingName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
                )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
        )
        .padding(.top, 6)
    }

    // MARK: - Controls row

    private var controlRow: some View {
        HStack(spacing: 18) {
            CircleIconButtonLarge(
                systemImage: isPaused ? "play.fill" : "pause.fill",
                size: 64
            ) {
                togglePause()
            }

            Button {
                stopRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.systemRed))
                        .frame(width: 88, height: 88)
                        .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 10)

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop")

            CircleIconButtonLarge(
                systemImage: isBookmarked ? "bookmark.fill" : "bookmark",
                size: 64
            ) {
                withAnimation(.snappy(duration: 0.18)) {
                    isBookmarked.toggle()
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Finish button

    private var finishButton: some View {
        Button {
            finish()
        } label: {
            Text("Finish Recording")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemIndigo), Color(.systemPurple)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    // MARK: - Actions

    private func togglePause() {
        withAnimation(.snappy(duration: 0.18)) {
            isPaused.toggle()
        }
        startTimerIfNeeded()
    }

    private func stopRecording() {
        // тут обычно: RecordingService.stop()
        isPaused = true
        startTimerIfNeeded()
    }

    private func finish() {
        // тут обычно: RecordingService.stop() + FileManagerService.create/save metadata
        dismiss()
    }

    // MARK: - Timer / Pulse

    private func startTimerIfNeeded() {
        if isPaused {
            stopTimer()
            return
        }
        if timer != nil { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Small UI

private struct CircleIconButtonLarge: View {
    let systemImage: String
    var size: CGFloat = 64
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(.label))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 8)
                )
                .overlay(
                    Circle()
                        .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NewRecordingView(viewModel: NewRecordingViewModel())
    }
}
