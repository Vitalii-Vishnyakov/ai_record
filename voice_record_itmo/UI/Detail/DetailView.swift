//
//  DetailView.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

// MARK: - Detail Screen

struct DetailView: View {
    @StateObject var viewModel: DetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var tab: SummaryTab = .transcript
    @State private var playback: PlaybackState = .init(
        title: "Team Meeting Notes",
        dateLine: "Today at 2:34 PM • 12:34",
        currentTime: 5 * 60 + 42,
        totalTime: 12 * 60 + 34,
        progress: 0.45,
        speed: 1.0
    )

    @State private var transcript: [TranscriptLine] = [
        .init(time: "00:00", text: "Hello everyone, thank you for joining today's meeting. I wanted to discuss our progress on the new product launch and go over some key milestones we need to hit before the end of the quarter."),
        .init(time: "00:23", text: "First, let's talk about the marketing strategy. Sarah, can you give us an update on the social media campaign? I know you've been working hard on the content."),
        .init(time: "01:05", text: "Great. Next, we should review QA status and any blockers. Please flag anything that might impact the release timeline."),
        .init(time: "02:10", text: "Customer support onboarding is going well. We'll have three new specialists ready next week.")
    ]

    @State private var summary = AISummary(
        keyPoints: [
            "Product launch scheduled for end of quarter with all teams aligned",
            "Marketing campaign secured partnerships with 5 major influencers",
            "QA process on track with minor bugs being addressed",
            "Customer support infrastructure enhanced with 3 new specialists"
        ]
    )

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        header

                        playerCard

                        segmentedTabs

                        contentCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CircleIconButton(systemImage: "chevron.left") {
                    dismiss()
                }

                Spacer()

                CircleIconButton(systemImage: "square.and.arrow.up") { }
                CircleIconButton(systemImage: "ellipsis") { }
            }

            Text(playback.title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color(.label))

            Text(playback.dateLine)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.top, 6)
    }

    // MARK: - Player Card

    private var playerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Button {
                    playback.isPlaying.toggle()
                } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(.systemIndigo), Color(.systemPurple)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 66, height: 66)

                        Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.leading, playback.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    ProgressBar(value: playback.progress)
                        .frame(height: 10)

                    HStack {
                        Text(formatTime(playback.currentTime))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))

                        Spacer()

                        Text(formatTime(playback.totalTime))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }

            HStack(spacing: 16) {
                PlayerChipButton(systemImage: "backward.fill") {
                    // seek -15
                    playback.currentTime = max(0, playback.currentTime - 15)
                    playback.progress = Double(playback.currentTime) / Double(max(1, playback.totalTime))
                }

                PlayerChipButton(systemImage: "gobackward") {
                    // rewind (demo: -5s)
                    playback.currentTime = max(0, playback.currentTime - 5)
                    playback.progress = Double(playback.currentTime) / Double(max(1, playback.totalTime))
                }

                SpeedChip(value: playback.speed) {
                    cycleSpeed()
                }

                PlayerChipButton(systemImage: "goforward") {
                    // forward (demo: +5s)
                    playback.currentTime = min(playback.totalTime, playback.currentTime + 5)
                    playback.progress = Double(playback.currentTime) / Double(max(1, playback.totalTime))
                }

                PlayerChipButton(systemImage: "forward.fill") {
                    // seek +15
                    playback.currentTime = min(playback.totalTime, playback.currentTime + 15)
                    playback.progress = Double(playback.currentTime) / Double(max(1, playback.totalTime))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
        )
    }

    // MARK: - Tabs

    private var segmentedTabs: some View {
        HStack(spacing: 12) {
            SegmentButton(
                title: "Full Transcript",
                isSelected: tab == .transcript
            ) { withAnimation(.snappy(duration: 0.18)) { tab = .transcript } }

            SegmentButton(
                title: "Summary",
                isSelected: tab == .summary
            ) { withAnimation(.snappy(duration: 0.18)) { tab = .summary } }
        }
    }

    // MARK: - Content Card

    private var contentCard: some View {
        Group {
            switch tab {
            case .transcript:
                transcriptCard
            case .summary:
                summaryCard
            }
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Full Transcript")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(.label))

                Spacer()

                Button("Copy") {
                    // copy transcript
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(.systemIndigo))
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(transcript) { line in
                    TranscriptRow(time: line.time, text: line.text)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
        )
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(.systemIndigo))

                Text("AI Summary")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(.label))

                Spacer()

                Button("Copy") {
                    // copy summary
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(.systemIndigo))
            }

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(.systemGreen))

                Text("Key Points")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(.label))
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(summary.keyPoints.indices, id: \.self) { idx in
                    BulletRow(text: summary.keyPoints[idx])
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemIndigo).opacity(0.08),
                            Color(.systemBlue).opacity(0.06),
                            Color(.systemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(.systemIndigo).opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func cycleSpeed() {
        let speeds: [Double] = [1.0, 1.25, 1.5, 0.75]
        if let idx = speeds.firstIndex(of: playback.speed) {
            playback.speed = speeds[(idx + 1) % speeds.count]
        } else {
            playback.speed = 1.0
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Components

private struct SegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? Color(.systemBackground) : Color(.label))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelected ? Color(.systemIndigo) : Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(.separator).opacity(isSelected ? 0 : 1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isSelected ? 0.10 : 0.0), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct TranscriptRow: View {
    let time: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(time)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

            Text(text)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.label))
                .lineSpacing(4)

            Spacer(minLength: 0)
        }
    }
}

private struct BulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(.systemIndigo))
                .frame(width: 8, height: 8)
                .padding(.top, 8)

            Text(text)
                .font(.system(size: 18))
                .foregroundStyle(Color(.label))
                .lineSpacing(4)

            Spacer(minLength: 0)
        }
    }
}

private struct PlayerChipButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(.label))
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }
}

private struct SpeedChip: View {
    let value: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(String(format: "%.2gx", value).replacingOccurrences(of: ".0x", with: "x"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(.label))
                .frame(width: 72, height: 56)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Models

private struct TranscriptLine: Identifiable {
    let id = UUID()
    let time: String
    let text: String
}

private struct AISummary {
    let keyPoints: [String]
}

// MARK: - Preview

#Preview {
    DetailView(viewModel: DetailViewModel())
}
