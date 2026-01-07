//
//  MainViewModel.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

final class MainViewModel: ObservableObject {
    @Published var filteredItems: [RecordingViewItem] = [
        .init(title: "Team Meeting Notes", dateText: "Today at 2:34 PM", words: 2345, language: "English", progress: 0.55, isStarred: true),
        .init(title: "Interview with Sarah", dateText: "Yesterday at 4:15 PM", words: 4892, language: "English", progress: 0.18, isStarred: false),
        .init(title: "Lecture Notes - AI", dateText: "Dec 15, 2024 at 10:30 AM", words: 8234, language: "English", progress: 0.82, isStarred: true),
        .init(title: "Quick Voice Memo", dateText: "Dec 14, 2024 at 3:22 PM", words: 342, language: "English", progress: 0.90, isStarred: false),
        .init(title: "Podcast Episode Draft", dateText: "Dec 13, 2024 at 9:00 AM", words: 12567, language: "English", progress: 0.25, isStarred: false),
        .init(title: "Client Call Summary", dateText: "Dec 12, 2024 at 2:45 PM", words: 3421, language: "English", progress: 0.05, isStarred: true)
    ]
    
    @Published var selectedFilter: Filter = .all
    
    @Published var items: [RecordingViewItem] = [
        .init(title: "Team Meeting Notes", dateText: "Today at 2:34 PM", words: 2345, language: "English", progress: 0.55, isStarred: true),
        .init(title: "Interview with Sarah", dateText: "Yesterday at 4:15 PM", words: 4892, language: "English", progress: 0.18, isStarred: false),
        .init(title: "Lecture Notes - AI", dateText: "Dec 15, 2024 at 10:30 AM", words: 8234, language: "English", progress: 0.82, isStarred: true),
        .init(title: "Quick Voice Memo", dateText: "Dec 14, 2024 at 3:22 PM", words: 342, language: "English", progress: 0.90, isStarred: false),
        .init(title: "Podcast Episode Draft", dateText: "Dec 13, 2024 at 9:00 AM", words: 12567, language: "English", progress: 0.25, isStarred: false),
        .init(title: "Client Call Summary", dateText: "Dec 12, 2024 at 2:45 PM", words: 3421, language: "English", progress: 0.05, isStarred: true)
    ]
    
    private var router: Router?
    
    func setRouter(router: Router) {
        self.router = router
    }
}
