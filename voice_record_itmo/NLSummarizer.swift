//
//  NLSummarizer.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 4.12.25.
//

import Foundation
import NaturalLanguage

final class NLSummarizer {

    /// Основной метод суммаризации
    /// - Parameters:
    ///   - text: исходный текст
    ///   - maxSentences: сколько предложений вернуть
    /// - Returns: суммаризированный текст
    static func summarize(_ text: String, maxSentences: Int = 3) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return "" }

        // Определяем язык (пусть система сама решит)
        let language = NLLanguage.russian

        // 1. Разбиваем текст на предложения
        let sentences = splitIntoSentences(cleaned)
        guard sentences.count > maxSentences else { return cleaned }

        // 2. Строим частотный словарь важных слов по всему тексту
        let wordFrequencies = buildWordFrequencies(in: cleaned, language: language)

        // 3. Считаем "важность" каждого предложения
        struct ScoredSentence {
            let index: Int
            let text: String
            let score: Double
        }

        var scored: [ScoredSentence] = []

        for (index, sentence) in sentences.enumerated() {
            let score = scoreSentence(sentence, frequencies: wordFrequencies, language: language)
            scored.append(ScoredSentence(index: index, text: sentence, score: score))
        }

        // 4. Выбираем топ N предложений по score
        let top = scored
            .sorted { $0.score > $1.score }
            .prefix(maxSentences)
            .sorted { $0.index < $1.index }  // восстановить порядок

        let result = top.map { $0.text.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")

        return result
    }

    // MARK: - Разбиение на предложения

    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        return sentences
    }

    // MARK: - Частотный словарь

    private static func buildWordFrequencies(in text: String, language: NLLanguage) -> [String: Int] {
        var frequencies: [String: Int] = [:]

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        tagger.setLanguage(language, range: text.startIndex..<text.endIndex)

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: options) { tag, tokenRange in
            guard let tag = tag else { return true }

            // Считаем только содержательные части речи
            let allowed: [NLTag] = [.noun, .verb, .adjective, .adverb]
            guard allowed.contains(tag) else { return true }

            let token = String(text[tokenRange])
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !token.isEmpty else { return true }

            frequencies[token, default: 0] += 1
            return true
        }

        return frequencies
    }

    // MARK: - Оценка предложения

    private static func scoreSentence(_ sentence: String,
                                      frequencies: [String: Int],
                                      language: NLLanguage) -> Double {
        guard !sentence.isEmpty else { return 0 }

        var score: Double = 0
        var wordCount = 0

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = sentence
        tagger.setLanguage(language, range: sentence.startIndex..<sentence.endIndex)

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther]

        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: options) { tag, tokenRange in
            guard let tag = tag else { return true }

            let allowed: [NLTag] = [.noun, .verb, .adjective, .adverb]
            guard allowed.contains(tag) else { return true }

            let token = String(sentence[tokenRange])
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !token.isEmpty else { return true }

            let freq = frequencies[token, default: 0]
            score += Double(freq)
            wordCount += 1

            return true
        }

        // Нормируем на длину, чтобы огромные предложения не выигрывали всегда
        if wordCount > 0 {
            score /= Double(wordCount)
        }

        return score
    }
}
