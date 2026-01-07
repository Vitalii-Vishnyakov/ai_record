//
//  DetailFactory.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import UIKit

enum DetailFactory {
    static func getDetailViewController() -> UIViewController {
        let viewModel = DetailViewModel()
        let viewController = DetailViewController(rootView: DetailView(viewModel: viewModel))
        return viewController
    }
}
