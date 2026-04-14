//
//  MainFactory.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import UIKit

enum MainFactory {
    @MainActor static func buildMainViewController(parentRouter: Router) -> UIViewController {
        let viewModel = MainViewModel(
            router: parentRouter,
            facade: AppDependencies.facade,
            player: AppDependencies.recordingService
        )
        let viewController = MainViewController(rootView: MainView(viewModel: viewModel))
        return viewController
    }
}
