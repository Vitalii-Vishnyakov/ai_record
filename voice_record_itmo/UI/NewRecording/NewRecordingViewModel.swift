//
//  NewRecordingViewModel.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

final class NewRecordingViewModel: ObservableObject {
    @Published var neuralStatue: NeuralStatus = .idle
    @Published var elapsedSeconds: Int = 42
    @Published var isPaused: Bool = false
    @Published var isBookmarked: Bool = false
    @Published var recordingName: String = ""

    @Published var pulse: Bool = false
    @Published var timer: Timer?
    @Published var pulseTimer: Timer?
    
    private weak var router: Router?
    
    init(router: Router?) {
        self.router = router
    }
    
    func startTimerIfNeeded() {
        if isPaused {
            stopTimer()
            return
        }
        if timer != nil { return }
        if pulseTimer != nil { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.elapsedSeconds += 1
        }
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            self.pulse.toggle()
        }
        
        RunLoop.main.add(timer!, forMode: .common)
        RunLoop.main.add(pulseTimer!, forMode: .common)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
    
    func startPulse() {
        pulse = false
    }
    
    func goGack() {
        router?.pop()
    }
}
