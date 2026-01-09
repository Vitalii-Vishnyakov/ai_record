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
    
    var body: some View {
        VStack(spacing: .zero) {
            AIModelStatus(neuralStatus: viewModel.neuralStatue)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    
                    playerCard
                    
                    segmentedTabs
                    
                    contentCard
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarHidden(true)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CircleIconButton(systemImage: "chevron.left") {
                    viewModel.onGoBack()
                }
                
                Spacer()
                
                CircleIconButton(systemImage: "square.and.arrow.up") { viewModel.onShareTap() }
            }
            
            Text(viewModel.playback.title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(.label))
            
            Text(viewModel.playback.dateLine)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.top, 10)
    }
    
    private var playerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Button(action: { viewModel.onPlayPauseTap() }) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemBlue).opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: viewModel.playback.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(.systemBlue))
                            .padding(.leading, 2)
                    }
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 10) {
                    ProgressBar(value: viewModel.playback.progress)
                        .frame(height: 6)
                    
                    HStack {
                        Text("\(viewModel.playback.currentTime)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(.secondaryLabel))
                        
                        Spacer()
                        
                        Text(viewModel.playback.dateLine)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(.secondaryLabel))
                        
                        Spacer()
                        
                        Text("\(viewModel.playback.totalTime)")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
            }
            
            HStack(spacing: 16) {
                PlayerChipButton(systemImage: "backward.fill") {
                    viewModel.onBackwardTap60()
                }
                
                PlayerChipButton(systemImage: "gobackward") {
                    viewModel.onBackwardTap15()
                }
                
                SpeedChip(value: viewModel.playback.speed) {
                    viewModel.onSpeedTap()
                }
                
                PlayerChipButton(systemImage: "goforward") {
                    viewModel.onForwardTap15()
                }
                
                PlayerChipButton(systemImage: "forward.fill") {
                    viewModel.onForwardTap60()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 8)
        )
    }
    
    // MARK: - Tabs
    
    private var segmentedTabs: some View {
        HStack(spacing: 12) {
            SegmentButton(
                title: L10n.transcriptFull.text,
                isSelected: viewModel.tab == .transcript
            ) { withAnimation(.snappy(duration: 0.18)) { viewModel.onTagTap(tab: .transcript) } }
            
            SegmentButton(
                title: L10n.summaryTitle.text,
                isSelected: viewModel.tab == .summary
            ) { withAnimation(.snappy(duration: 0.18)) { viewModel.onTagTap(tab: .summary) } }
        }
    }
    
    // MARK: - Content Card
    
    private var contentCard: some View {
        Group {
            switch viewModel.tab {
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
                Text(L10n.transcriptFull.text)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(.label))
                
                Spacer()
                
                Button(L10n.copy.text) {
                    viewModel.copyTap()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(.systemBlue))
            }
            
            VStack(alignment: .leading, spacing: 16) {
//                ForEach(viewModel.transcript) { line in
//                    TranscriptRow(time: line.time, text: line.text)
//                }
                
                Text(viewModel.transcript)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color(.label))
                    .lineSpacing(4)
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
                
                Text(L10n.aiSummary.text)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(.label))
                
                Spacer()
                
                Button(L10n.copy.text) {
                    viewModel.copyTap()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(.systemBlue))
            }
            
            Text(viewModel.summary.text)
                .font(.system(size: 18))
                .foregroundStyle(Color(.label))
                .lineSpacing(4)
            
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(.systemGreen))
                
                Text(L10n.keywords.text)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(.label))
            }
            .padding(.top, 2)
            
            TagCloudView(tags: viewModel.summary.keyWords)
         
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
                .padding(.vertical, 12)
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
                .font(.system(size: 16, weight: .regular))
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

private struct PlayerChipButton: View {
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(.label))
                .frame(width: 44, height: 44)
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
