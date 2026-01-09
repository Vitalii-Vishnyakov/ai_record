//
//  UIApplication+Ext.swift
//  voice_record_itmo
//
//  Created by Виталий Вишняков on 8.01.26.
//

import UIKit

extension UIApplication {
    var safeArea: UIEdgeInsets? {
        let window = UIApplication.shared.windows.first
        return window?.safeAreaInsets
    }
}
