//
//  Router.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 7.01.26.
//

import UIKit

protocol Router: NSObject {
    func push(viewController: UIViewController)
    func pop()
}

extension UINavigationController: Router {
    func push(viewController: UIViewController) {
        pushViewController(viewController, animated: true)
    }
    
    func pop() {
        popViewController(animated: true)
    }
}
