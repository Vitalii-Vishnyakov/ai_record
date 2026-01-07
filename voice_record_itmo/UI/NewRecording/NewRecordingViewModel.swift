//
//  NewRecordingViewModel.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

final class NewRecordingViewModel: ObservableObject {
    private var router: Router?
    
    func setRouter(router: Router) {
        self.router = router
    }
}
