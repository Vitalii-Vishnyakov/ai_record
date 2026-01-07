//
//  FilterChip.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

enum Filter: CaseIterable, Identifiable {
    case all, today, thisWeek, starred
    
    var id: String {
        title
    }
    var title: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .starred: return "Starred"
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color(.systemBackground) : Color(.label))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color(.systemBlue) : Color(.systemBackground))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color(.separator).opacity(isSelected ? 0 : 1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
