//
//  NewRecordingFactory.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import UIKit

enum NewRecordingFactory {
    @MainActor static func getNewRecordingViewController(parentRouter: Router?) -> UIViewController {
        let audioManager = FileManagerService()
        let metaDataManager = MetaDataFileManager()
        let facade = FileManagerFacade(files: audioManager, metadataStore: metaDataManager)
        let recordService = RecordingService()
        
        let viewModel = NewRecordingViewModel(router: parentRouter, facade: facade, recorder: recordService)
        let viewController = NewRecordingViewController(rootView: NewRecordingView(viewModel: viewModel))
        return viewController
    }
}
