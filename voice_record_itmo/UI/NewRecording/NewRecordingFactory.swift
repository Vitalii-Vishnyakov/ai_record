//
//  NewRecordingFactory.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import UIKit

enum NewRecordingFactory {
    static func getNewRecordingViewController() -> UIViewController {
        let viewModel = NewRecordingViewModel()
        let viewController = NewRecordingViewController(rootView: NewRecordingView(viewModel: viewModel))
        return viewController
    }
}
