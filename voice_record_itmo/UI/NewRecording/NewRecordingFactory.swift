//
//  NewRecordingFactory.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import UIKit

enum NewRecordingFactory {
    @MainActor static func getNewRecordingViewController(parentRouter: Router?) -> UIViewController {
        let viewModel = NewRecordingViewModel(
            router: parentRouter,
            facade: AppDependencies.facade,
            recorder: AppDependencies.recordingService
        )
        let viewController = NewRecordingViewController(rootView: NewRecordingView(viewModel: viewModel))
        return viewController
    }
}
