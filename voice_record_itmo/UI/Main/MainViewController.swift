//
//  MainViewController.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import SwiftUI

final class MainViewController: UIHostingController<MainView> {
    override init(rootView: MainView) {
        super.init(rootView: rootView)
        rootView.viewModel.setRouter(router: self)
    }
    
    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
