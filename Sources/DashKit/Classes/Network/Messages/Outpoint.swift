//
//  Outpoint.swift
//  DashKit
//
//  Created by Sun on 2024/8/21.
//

import Foundation

import BitcoinCore

class Outpoint {
    let txHash: Data
    let vout: UInt32

    init(txHash: Data, vout: UInt32) {
        self.txHash = txHash
        self.vout = vout
    }

    init(byteStream: ByteStream) {
        txHash = byteStream.read(Data.self, count: 32)
        vout = byteStream.read(UInt32.self)
    }
}
