//
//  DetailViewModel.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

final class DetailViewModel: ObservableObject {
    @Published var neuralStatue: NeuralStatus = .idle
    @Published var tab: SummaryTab = .summary
    @Published var playback: PlaybackState = .init(
        title: "Team Meeting Notes",
        dateLine: "Today at 2:34 PM • 12:34",
        currentTime: 5 * 60 + 42,
        totalTime: 12 * 60 + 34,
        progress: 0.45,
        speed: 1.0
    )

    @Published var transcript: [TranscriptLine] = [
        .init(id: "asdf", time: "00:00", text: "Hello everyone, thank you for joining today's meeting. I wanted to discuss our progress on the new product launch and go over some key milestones we need to hit before the end of the quarter."),
        .init(id: "asdddf", time: "00:23", text: "First, let's talk about the marketing strategy. Sarah, can you give us an update on the social media campaign? I know you've been working hard on the content."),
        .init(id: "addsdf", time: "01:05", text: "Great. Next, we should review QA status and any blockers. Please flag anything that might impact the release timeline."),
        .init(id: "asdfrr", time: "02:10", text: "Customer support onboarding is going well. We'll have three new specialists ready next week.")
    ]

    @Published var summary = AISummary(
        text: "Customer support onboarding is going well. We'll have three new specialists ready next week.",
        keyWords: ["support", "going", "week", ""]
    )
    
    
    private weak var router: Router?
    
    init(router: Router?) {
        self.router = router
    }
    
    func onGoBack() {
        router?.pop()
    }
    
    func onShareTap() {
        
    }
    
    func onPlayPauseTap() {
        
    }
    
    func onForwardTap15() {
        
    }
    
    func onForwardTap60() {
        
    }
    
    func onBackwardTap15() {
        
    }
    
    func onBackwardTap60() {
        
    }
    
    func onSpeedTap() {
        
    }
    
    func onSkip(newTimeInterval: TimeInterval) {
        
    }
    
    func onTagTap(tab: SummaryTab) {
        self.tab = tab
    }
    
    func copyTap() {
        
    }
}
