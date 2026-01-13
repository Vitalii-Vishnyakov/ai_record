//
//  RecordingRowView.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

struct RecordingRowView: View {
    let item: RecordingViewItem
    let onPlay: (String) -> Void
    let onStared: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                    
                    Text(item.dateText)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                
                Spacer()
                
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(item.isStarred ? .systemYellow : .systemGray4))
                    .padding(.top, 2)
                    .onTapGesture {
                        onStared(item.id)
                    }
            }
            
            HStack(spacing: 12) {
                Button(action: { onPlay(item.id) }) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemBlue).opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: item.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(.systemBlue))
                            .padding(.leading, 2)
                    }
                }
                .buttonStyle(.plain)
                
                ProgressBar(value: item.progress)
                    .frame(height: 6)
                
                Spacer(minLength: 0)
            }
            
            HStack(spacing: 10) {
                if item.isTranscribed {
                    MetaPill(
                        systemImage: "text.viewfinder",
                        text: L10n.recordingRecognized.text
                    )
                }
                
                if item.isSummurized {
                    MetaPill(systemImage: "text.redaction", text: L10n.recordingSummarized.text)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(item.isTranscribed && item.isSummurized ? .systemGreen : .systemYellow))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private func formatWords(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct MetaPill: View {
    let systemImage: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
