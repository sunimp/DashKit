//
//  RequestMasternodeListDiffTask.swift
//
//  Created by Sun on 2019/3/18.
//

import Foundation

import BitcoinCore
import SWExtensions

class RequestMasternodeListDiffTask: PeerTask {
    // MARK: Properties

    let baseBlockHash: Data
    let blockHash: Data

    var masternodeListDiffMessage: MasternodeListDiffMessage? = nil

    // MARK: Lifecycle

    init(baseBlockHash: Data, blockHash: Data) {
        self.baseBlockHash = baseBlockHash
        self.blockHash = blockHash
    }

    // MARK: Overridden Functions

    override func start() {
        let message = GetMasternodeListDiffMessage(baseBlockHash: baseBlockHash, blockHash: blockHash)

        requester?.send(message: message)

        super.start()
    }

    override func handle(message: IMessage) -> Bool {
        if
            let message = message as? MasternodeListDiffMessage, message.baseBlockHash == baseBlockHash,
            message.blockHash == blockHash {
            masternodeListDiffMessage = message

            delegate?.handle(completedTask: self)
            return true
        }
        return false
    }
}
