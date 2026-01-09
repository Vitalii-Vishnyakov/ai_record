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

    init(
        title: String = "",
        dateLine: String = "",
        currentTime: Int = 0,
        totalTime: Int = 0,
        progress: Double = 0,
        speed: Double = 1.0,
        isPlaying: Bool = false
    ) {
        self.title = title
        self.dateLine = dateLine
        self.currentTime = currentTime
        self.totalTime = totalTime
        self.progress = progress
        self.speed = speed
        self.isPlaying = isPlaying
    }
}
