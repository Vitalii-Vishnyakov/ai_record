//
//  AIModelStatus.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 8.01.26.
//

import SwiftUI

struct AIModelStatus: View {
    let neuralStatus: NeuralStatus
    let currentProgress: Double
    
    var body: some View {
        HStack(spacing: .zero) {
            Text(neuralStatus.localizedText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(.label))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.blue.opacity(0.5))
                .frame(width: UIScreen.main.bounds.width * currentProgress, height: 4)
        }
        .animation(.smooth, value: currentProgress)
        .animation(.smooth, value: neuralStatus)
    }
    
    var backgroundColor: Color {
        switch neuralStatus {
        case .warmingUp:
            Color(.systemGray4)
        case .loadingModel:
            Color(.systemGray4)
        case .processingAudio:
            Color(.systemGray3)
            
        case .transcribing:
            Color(.systemGreen)
        case .summarizing:
            Color(.systemGreen)
        case .extractingKeywords:
            Color(.systemGreen)
            
        case .idle:
            Color(.systemGray2)
        case .done:
            Color(.systemBlue)
        case .error:
            Color(.systemRed)
        }
    }
}
