//
//  AddBlur.swift
//  NoNote
//
//  Created by Xie Liwei on 15/07/2018.
//  Copyright © 2018 Xie Liwei. All rights reserved.
//

import Foundation
import UIKit

func createBlursOnView(view: UIView) -> UIVisualEffectView {
    var blurEffect = UIBlurEffect()
    if #available(iOS 10.0, *) {
        blurEffect = UIBlurEffect(style: .regular)
    } else {
        blurEffect = UIBlurEffect(style: .light)
    }
    let blurEffectView = UIVisualEffectView(effect: blurEffect)
    let width = view.frame.width
    let height = view.frame.height
    blurEffectView.frame = CGRect(x: 0, y: 0, width: width, height: height)
    let blur = UIVibrancyEffect(blurEffect: blurEffect)
    let vibrancyView = UIVisualEffectView(effect: blur)
    vibrancyView.frame = CGRect(x: 0, y: 0, width: width, height: height)
    blurEffectView.contentView.addSubview(vibrancyView)
    return blurEffectView
}

func createDarkBlursOnView(view: UIView) -> UIVisualEffectView {
    let blurEffect = UIBlurEffect(style: .dark)
    
    let blurEffectView = UIVisualEffectView(effect: blurEffect)
    let width = view.frame.width
    let height = view.frame.height
    blurEffectView.frame = CGRect(x: 0, y: 0, width: width, height: height)
    let blur = UIVibrancyEffect(blurEffect: blurEffect)
    let vibrancyView = UIVisualEffectView(effect: blur)
    vibrancyView.frame = CGRect(x: 0, y: 0, width: width, height: height)
    blurEffectView.contentView.addSubview(vibrancyView)
    return blurEffectView
}
