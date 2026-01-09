//
//  AIModelStatus.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 8.01.26.
//

import SwiftUI

struct AIModelStatus: View {
    let neuralStatus: NeuralStatus
    
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
    }
    
    var backgroundColor: Color {
        switch neuralStatus {
        case .warmingUp:
            Color(.systemGray4)
        case .loadingModel:
            Color(.systemGray3)
        case .processingAudio:
            Color(.systemYellow)
        case .transcribing:
            Color(.green)
        case .summarizing:
            Color(.systemGreen)
        case .extractingKeywords:
            Color(.systemIndigo)
        case .idle:
            Color(.systemGray2)
        case .done:
            Color(.systemBlue)
        case .error:
            Color(.systemRed)
        }
    }
}
