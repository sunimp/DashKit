//
//  InstantSendLockHandler.swift
//
//  Created by Sun on 2019/5/28.
//

import Foundation

import BitcoinCore
import SWToolKit

class InstantSendLockHandler: IInstantSendLockHandler {
    // MARK: Properties

    public weak var delegate: IInstantTransactionDelegate?

    private let instantTransactionManager: IInstantTransactionManager
    private let instantLockManager: IInstantSendLockManager

    private let logger: Logger?

    // MARK: Lifecycle

    init(
        instantTransactionManager: IInstantTransactionManager,
        instantSendLockManager: IInstantSendLockManager,
        logger: Logger? = nil
    ) {
        self.instantTransactionManager = instantTransactionManager
        instantLockManager = instantSendLockManager
        self.logger = logger
    }

    // MARK: Functions

    public func handle(transactionHash: Data) {
        // get relayed lock for inserted transaction and check it
        if let lock = instantLockManager.takeRelayedLock(for: transactionHash) {
            validateSendLock(isLock: lock)
        }
    }

    public func handle(isLock: ISLockMessage) {
        // check transaction already not in instant
        guard !instantTransactionManager.isTransactionInstant(txHash: isLock.txHash) else {
            return
        }
        // do nothing if tx doesn't exist
        guard instantTransactionManager.isTransactionExists(txHash: isLock.txHash) else {
            instantLockManager.add(relayed: isLock)
            return
        }
        // validation
        validateSendLock(isLock: isLock)
    }

    private func validateSendLock(isLock: ISLockMessage) {
        do {
            try instantLockManager.validate(isLock: isLock)

            instantTransactionManager.makeInstant(txHash: isLock.txHash)
            delegate?.onUpdateInstant(transactionHash: isLock.txHash)
        } catch {
            logger?.error(error)
        }
    }
}
