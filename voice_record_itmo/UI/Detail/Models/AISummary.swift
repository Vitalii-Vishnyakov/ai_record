//
//  AISummary.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 8.01.26.
//

struct AISummary {
    let text: String
    let keyWords: [String]

    init(text: String = "", keyWords: [String] = []) {
        self.text = text
        self.keyWords = keyWords
    }
}
