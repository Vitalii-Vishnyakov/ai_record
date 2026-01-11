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
        VStack(spacing: .zero) {
            AIModelStatus(neuralStatus: viewModel.neuralStatus, currentProgress: viewModel.currentStatusProgress)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    header
                    
                    filterChips
                    
                    VStack(spacing: 12) {
                        ForEach(viewModel.filteredItems) { item in
                            RecordingRowView(
                                item: item,
                                onPlay: { viewModel.onPlayPauseTap(id: $0) },
                                onStared: { viewModel.onStaredTap(id: $0) }
                            )
                            .onTapGesture {
                                viewModel.onRecordTap(id: item.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 92)
            }
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .bottomTrailing) {
                recordButton
                    .padding(.trailing, 18)
                    .padding(.bottom, 18)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.onAppear()
        }
    }
    
    // MARK: - Parts
    
    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            if viewModel.isSearchPresented {
                TextField("Search...", text: $viewModel.searchText)
                    .textInputAutocapitalization(.sentences)
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
                    .onChange(of: viewModel.searchText) {
                        viewModel.onSearchTextChanged($0)
                    }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.appTitle.text)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(.label))
                    
                    Text(L10n.recordingsTitle.text)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            
            Spacer()
            
            CircleIconButton(systemImage: "magnifyingglass") { viewModel.onSearchTap() }
        }
        .animation(.smooth, value: viewModel.isSearchPresented)
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
                        withAnimation(.snappy(duration: 0.18)) { viewModel.onChipTap(filter: f) }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private var recordButton: some View {
        Button {
            viewModel.onNewRecordTap()
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
}
