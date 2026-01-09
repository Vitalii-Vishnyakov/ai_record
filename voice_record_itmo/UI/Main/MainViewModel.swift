//
//  MainViewModel.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

final class MainViewModel: ObservableObject {
    @Published var filteredItems: [RecordingViewItem] = [
        .init(
            id: "adsf",
            title: "Note",
            dateText: "Yestardae",
            duration: 40,
            progress: 0.5,
            isStarred: false,
            isTranscribed: true,
            isSummurized: true
        )
    ]
    
    @Published var neuralStatue: NeuralStatus = .idle
    
    @Published var selectedFilter: Filter = .all
    
    @Published var items: [RecordingViewItem] = [
        .init(
            id: "adsf",
            title: "Note",
            dateText: "Yestardae",
            duration: 40,
            progress: 0.5,
            isStarred: false,
            isTranscribed: true,
            isSummurized: true
        )
    ]
    
    private weak var router: Router?
    
    func onChipTap(filter: Filter) {
        
    }
    
    func onPlayPauseTap(id: String) {
        
    }
    
    func onStaredTap(id: String) {
        
    }
    
    func onRecordTap(id: String) {
        router?.push(viewController: DetailFactory.getDetailViewController(parentRouter: router))
    }
    
    func onNewRecordTap() {
        router?.push(viewController: NewRecordingFactory.getNewRecordingViewController(parentRouter: router))
    }
    
    func onSearchTap() {
        
    }
    
    init(router: Router?) {
        self.router = router
    }
}
