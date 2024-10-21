//
//  Configuration.swift
//  DashKit-Example
//
//  Created by Sun on 2024/8/21.
//

import UIKit

import BitcoinCore
import SWToolKit

class Configuration {
    static let shared = Configuration()

    let minLogLevel: Logger.Level = .verbose
    let testNet = false
    let defaultWords = [
        //        "current force clump paper shrug extra zebra employ prefer upon mobile hire",
        "popular game latin harvest silly excess much valid elegant illness edge silk",
    ]
}
