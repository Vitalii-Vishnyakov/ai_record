//
//  RecordingRowView.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

struct RecordingRowView: View {
    let item: RecordingViewItem
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
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
                
                if item.isStarred {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(.systemYellow))
                        .padding(.top, 2)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: onPlay) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemBlue).opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "play.fill")
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
                MetaPill(systemImage: "doc.text", text: "\(formatWords(item.words)) words")
                MetaPill(systemImage: "globe", text: item.language)
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(.systemGreen))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: onDelete) {
                Label("Delete", systemImage: "trash.fill")
            }
            .tint(Color(.systemRed))
            
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Color(.systemOrange))
        }
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
