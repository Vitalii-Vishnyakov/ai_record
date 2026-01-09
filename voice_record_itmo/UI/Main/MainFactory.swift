//
//  MainFactory.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import UIKit

enum MainFactory {
    @MainActor static func buildMainViewController(parentRouter: Router) -> UIViewController {
        let audioManager = FileManagerService()
        let metaDataManager = MetaDataFileManager()
        let facade = FileManagerFacade(files: audioManager, metadataStore: metaDataManager)
        let recordService = RecordingService()
        
        let viewModel = MainViewModel(router: parentRouter, facade: facade, player: recordService)
        let viewController = MainViewController(rootView: MainView(viewModel: viewModel))
        return viewController
    }
}
