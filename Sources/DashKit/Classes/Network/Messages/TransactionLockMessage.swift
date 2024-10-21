//
//  TransactionLockMessage.swift
//
//  Created by Sun on 2018/9/4.
//

import Foundation

import BitcoinCore
import SWExtensions

struct TransactionLockMessage: IMessage {
    // MARK: Properties

    let transaction: FullTransaction

    // MARK: Computed Properties

    var description: String {
        "\(transaction.header.dataHash.sw.reversedHex)"
    }
}
