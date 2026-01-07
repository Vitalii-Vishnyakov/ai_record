//
//  MainFactory.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import UIKit

enum MainFactory {
    static func buildMainViewController() -> UIViewController {
        let viewModel = MainViewModel()
        let viewController = MainViewController(rootView: MainView(viewModel: viewModel))
        return viewController
    }
}
