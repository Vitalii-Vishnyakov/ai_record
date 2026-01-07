//
//  ProgressBar.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

struct ProgressBar: View {
    let value: Double // 0...1
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color(.systemGray5))
                
                Capsule(style: .continuous)
                    .fill(Color(.systemBlue))
                    .frame(width: max(0, min(geo.size.width, geo.size.width * value)))
            }
        }
        .frame(height: 6)
    }
}
