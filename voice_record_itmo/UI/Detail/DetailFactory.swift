//
//  DetailFactory.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import UIKit

enum DetailFactory {
    @MainActor static func getDetailViewController(parentRouter: Router?, itemId: String) -> UIViewController {
        let audioManager = FileManagerService()
        let metaDataManager = MetaDataFileManager()
        let facade = FileManagerFacade(files: audioManager, metadataStore: metaDataManager)
        let recordService = RecordingService()
        
        let viewModel = DetailViewModel(router: parentRouter, facade: facade, player: recordService, itemId: itemId)
        let viewController = DetailViewController(rootView: DetailView(viewModel: viewModel))
        return viewController
    }
}
