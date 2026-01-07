//
//  ViewController.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 24.11.25.
//

enum AppStateValue {
    case modelLoading
    case transcribing
    case recording
    case summirizing
    case none
}

class AppState {
    static let shared = AppState()
    
    private init() {}
    
    var state: AppStateValue = .none {
        didSet {
            DispatchQueue.main.async {
                self.observer(self.state)
            }
        }
    }
    
    var observer: (AppStateValue) -> Void = { _ in }
}

import UIKit

protocol ViewPresentationDelegate: AnyObject {
    func showSummarizedText(text: String)
}

class ViewController: RecordViewController {
    private var voiceHelper: VoiceHelper?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        voiceHelper = VoiceHelper(delegate: self)
    }
    
    override func sendUrl(url: URL) {
        voiceHelper?.decode(url: url)
    }
    
    override func runLocalTest() {
        if let url = Bundle.main.url(forResource: "record", withExtension: "wav") {
            voiceHelper?.decode(url: url)
        }
    }
}

extension ViewController: ViewPresentationDelegate {
    func showSummarizedText(text: String) {
        self.showSummText(text: text)
    }
}
