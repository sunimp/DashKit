//
//  SingleHasher.swift
//
//  Created by Sun on 2019/4/12.
//

import Foundation

import BitcoinCore
import SWCryptoKit

class SingleHasher: IDashHasher {
    func hash(data: Data) -> Data {
        Crypto.sha256(data)
    }
}
