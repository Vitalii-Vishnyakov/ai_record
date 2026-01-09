//
//  NewRecordingView.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

struct NewRecordingView: View {
    @StateObject var viewModel: NewRecordingViewModel
    
    var body: some View {
        VStack(spacing: .zero) {
            AIModelStatus(neuralStatus: viewModel.neuralStatue)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    titleRow
                    
                    micPulse
                    
                    timeBlock
                    
                    nameCard
                    
                    controlRow
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            viewModel.startPulse()
            viewModel.startTimerIfNeeded()
        }
        .onDisappear {
            viewModel.stopTimer()
        }
        .navigationBarHidden(true)
    }
    
    
    private var titleRow: some View {
        ZStack {
            Text(L10n.newRecordingTitle.text)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(.label))
            
            HStack {
                CircleIconButton(systemImage: "chevron.left") {
                    viewModel.goGack()
                }
                Spacer()
            }
        }
        .padding(.top, 12)
    }
    
    private var micPulse: some View {
        ZStack {
            Circle()
                .fill(Color(.systemIndigo).opacity(viewModel.pulse ? 0.18 : 0.12))
                .frame(width: 240, height: 240)
                .scaleEffect(viewModel.pulse ? 1.08 : 0.92)
            
            Circle()
                .fill(Color(.systemBlue).opacity(viewModel.pulse ? 0.22 : 0.16))
                .frame(width: 200, height: 200)
                .scaleEffect(viewModel.pulse ? 1.05 : 0.95)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(.systemIndigo), Color(.systemBlue)],
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
        .animation(.smooth(duration: 2), value: viewModel.pulse)
    }
    
    private var timeBlock: some View {
        VStack(spacing: 8) {
            Text(formatTime(viewModel.elapsedSeconds))
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(Color(.label))
            
            Text(viewModel.isPaused ? L10n.recordPaused.text : L10n.recordingInProgress.text)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .animation(.linear(duration: 0.1), value: viewModel.elapsedSeconds)
    }
    
    // MARK: - Name card
    
    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.recordingName.text)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(.label))
            
            TextField(L10n.recordingNamePlaceholder.text, text: $viewModel.recordingName)
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
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
        )
        .padding(.top, 6)
    }
    
    private var controlRow: some View {
        HStack(spacing: 18) {
            CircleIconButtonLarge(
                systemImage: viewModel.isPaused ? "play.fill" : "pause.fill",
                size: 64
            ) {
                
            }
            
            Button {
                
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
                systemImage: viewModel.isBookmarked ? "bookmark.fill" : "bookmark",
                size: 64
            ) {
                withAnimation(.snappy(duration: 0.18)) {
     
                }
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Formatting
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

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
        NewRecordingView(viewModel: NewRecordingViewModel(router: nil))
    }
}
