//
//  MainView.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

struct MainView: View {
    @StateObject var viewModel: MainViewModel
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    header
                
                    filterChips
                    
                    VStack(spacing: 12) {
                        ForEach(viewModel.filteredItems) { item in
                            RecordingRowView(
                                item: item,
                                onPlay: { /* play */ },
                                onEdit: { /* edit */ },
                                onDelete: { delete(item) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 92) // space for floating button + tabbar
            }
            
            recordButton
                .padding(.trailing, 18)
                .padding(.bottom, 18)
        }
        .navigationBarHidden(true)
        .background(Color(.systemGroupedBackground))
        
    }
    
    // MARK: - Parts
    
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Voice Recorder")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(.label))
                
                Text("Your recordings")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                CircleIconButton(systemImage: "magnifyingglass") { }
                CircleIconButton(systemImage: "ellipsis") { }
            }
        }
        .padding(.top, 10)
    }
        
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Filter.allCases) { f in
                    FilterChip(
                        title: f.title,
                        isSelected: viewModel.selectedFilter == f
                    ) {
                        withAnimation(.snappy(duration: 0.18)) { viewModel.selectedFilter = f }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var recordButton: some View {
        Button {
            // start recording
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color(.systemBlue))
                        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
                )
        }
        .accessibilityLabel("Record")
    }
    
    
    private func delete(_ item: RecordingViewItem) {
        withAnimation(.snappy) {
            viewModel.items.removeAll { $0.id == item.id }
        }
    }
}

// MARK: - Preview

#Preview {
    MainView(viewModel: MainViewModel())
}
