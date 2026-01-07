//
//  PlaybackState.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

struct PlaybackState {
    var title: String
    var dateLine: String
    var currentTime: Int
    var totalTime: Int
    var progress: Double
    var speed: Double
    var isPlaying: Bool = false
}
