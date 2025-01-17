//
//  Kit.swift
//
//  Created by Sun on 2019/3/18.
//

import Foundation

import BigInt
import BitcoinCore
import HDWalletKit
import SWToolKit

// MARK: - Kit

public class Kit: AbstractKit {
    // MARK: Nested Types

    public enum NetworkType: String, CaseIterable {
        case mainNet
        case testNet

        // MARK: Computed Properties

        var network: INetwork {
            switch self {
            case .mainNet:
                MainNet()
            case .testNet:
                TestNet()
            }
        }
    }

    // MARK: Static Properties

    private static let name = "DashKit"
    private static let heightInterval = 24 // Blocks count in window for calculating difficulty
    private static let targetSpacing = 150 // Time to mining one block ( 2.5 min. Dash )
    private static let maxTargetBits = 0x1E0FFFFF // Initially and max. target difficulty for blocks ( Dash )

    // MARK: Properties

    public weak var delegate: DashKitDelegate?

    private let storage: IDashStorage

    private var masternodeSyncer: MasternodeListSyncer?
    private var instantSend: InstantSend?
    private let dashTransactionInfoConverter: ITransactionInfoConverter

    // MARK: Lifecycle

    public convenience init(
        seed: Data,
        walletID: String,
        syncMode: BitcoinCore.SyncMode = .api,
        networkType: NetworkType = .mainNet,
        confirmationsThreshold: Int = 6,
        logger: Logger?
    ) throws {
        let masterPrivateKey = HDPrivateKey(seed: seed, xPrivKey: Purpose.bip44.rawValue)

        try self.init(
            extendedKey: .private(key: masterPrivateKey),
            walletID: walletID,
            syncMode: syncMode,
            networkType: networkType,
            confirmationsThreshold: confirmationsThreshold,
            logger: logger
        )
    }

    public convenience init(
        extendedKey: HDExtendedKey,
        walletID: String,
        syncMode: BitcoinCore.SyncMode = .api,
        networkType: NetworkType = .mainNet,
        confirmationsThreshold: Int = 6,
        logger: Logger?
    ) throws {
        try self.init(
            extendedKey: extendedKey,
            watchAddressPublicKey: nil,
            walletID: walletID,
            syncMode: syncMode,
            networkType: networkType,
            confirmationsThreshold: confirmationsThreshold,
            logger: logger
        )
    }

    public convenience init(
        watchAddress: String,
        walletID: String,
        syncMode: BitcoinCore.SyncMode = .api,
        networkType: NetworkType = .mainNet,
        confirmationsThreshold: Int = 6,
        logger: Logger?
    ) throws {
        let network = networkType.network
        let base58AddressConverter = Base58AddressConverter(
            addressVersion: network.pubKeyHash,
            addressScriptVersion: network.scriptHash
        )
        let address = try base58AddressConverter.convert(address: watchAddress)
        let publicKey = try WatchAddressPublicKey(data: address.lockingScriptPayload, scriptType: address.scriptType)

        try self.init(
            extendedKey: nil,
            watchAddressPublicKey: publicKey,
            walletID: walletID,
            syncMode: syncMode,
            networkType: networkType,
            confirmationsThreshold: confirmationsThreshold,
            logger: logger
        )
    }

    private init(
        extendedKey: HDExtendedKey?,
        watchAddressPublicKey: WatchAddressPublicKey?,
        walletID: String,
        syncMode: BitcoinCore.SyncMode = .api,
        networkType: NetworkType = .mainNet,
        confirmationsThreshold: Int = 6,
        logger: Logger?
    ) throws {
        let network = networkType.network
        let logger = logger ?? Logger(minLogLevel: .verbose)
        let databaseFilePath = try DirectoryHelper.directoryURL(for: Kit.name)
            .appendingPathComponent(Kit.databaseFileName(
                walletID: walletID,
                networkType: networkType,
                syncMode: syncMode
            )).path
        let storage = DashGrdbStorage(databaseFilePath: databaseFilePath)
        self.storage = storage
        let apiSyncStateManager = ApiSyncStateManager(
            storage: storage,
            restoreFromApi: network.syncableFromApi && syncMode != BitcoinCore.SyncMode.full
        )

        let apiTransactionProvider: IApiTransactionProvider
        switch networkType {
        case .mainNet:
            let apiTransactionProviderURL = "https://insight.dash.org/insight-api"

            if case .blockchair = syncMode {
                let blockchairApi = BlockchairApi(chainID: network.blockchairChainID, logger: logger)
                let blockchairBlockHashFetcher = BlockchairBlockHashFetcher(blockchairApi: blockchairApi)
                let blockchairProvider = BlockchairTransactionProvider(
                    blockchairApi: blockchairApi,
                    blockHashFetcher: blockchairBlockHashFetcher
                )
                let insightApiProvider = InsightApi(url: apiTransactionProviderURL, logger: logger)

                apiTransactionProvider = BiApiBlockProvider(
                    restoreProvider: insightApiProvider,
                    syncProvider: blockchairProvider,
                    apiSyncStateManager: apiSyncStateManager
                )
            } else {
                apiTransactionProvider = InsightApi(url: apiTransactionProviderURL, logger: logger)
            }

        case .testNet:
            apiTransactionProvider = InsightApi(url: "http://dash-testnet.horizontalsystems.xyz/apg", logger: logger)
        }

        let paymentAddressParser = PaymentAddressParser(validScheme: "dash", removeScheme: true)

        let singleHasher = SingleHasher() // Use single sha256 for hash
        let doubleShaHasher = DoubleShaHasher() // Use doubleSha256 for hash
        let x11Hasher = X11Hasher() // Use for block header hash

        let instantSendFactory = InstantSendFactory()
        let instantTransactionState = InstantTransactionState()
        let instantTransactionManager = InstantTransactionManager(
            storage: storage,
            instantSendFactory: instantSendFactory,
            instantTransactionState: instantTransactionState
        )

        dashTransactionInfoConverter =
            DashTransactionInfoConverter(instantTransactionManager: instantTransactionManager)

        let difficultyEncoder = DifficultyEncoder()

        let blockValidatorSet = BlockValidatorSet()
        blockValidatorSet.add(blockValidator: ProofOfWorkValidator(difficultyEncoder: difficultyEncoder))

        let blockValidatorChain = BlockValidatorChain()
        let blockHelper = BlockValidatorHelper(storage: storage)

        let targetTimespan = Kit.heightInterval * Kit.targetSpacing // Time to mining all 24 blocks in circle
        switch networkType {
        case .mainNet:
            blockValidatorChain.add(blockValidator: DarkGravityWaveValidator(
                encoder: difficultyEncoder,
                blockHelper: blockHelper,
                heightInterval: Kit.heightInterval,
                targetTimeSpan: targetTimespan,
                maxTargetBits: Kit.maxTargetBits,
                powDGWHeight: 68589
            ))

        case .testNet:
            blockValidatorChain.add(blockValidator: DarkGravityWaveTestNetValidator(
                difficultyEncoder: difficultyEncoder,
                targetSpacing: Kit.targetSpacing,
                targetTimeSpan: targetTimespan,
                maxTargetBits: Kit.maxTargetBits,
                powDGWHeight: 4002
            ))
            blockValidatorChain.add(blockValidator: DarkGravityWaveValidator(
                encoder: difficultyEncoder,
                blockHelper: blockHelper,
                heightInterval: Kit.heightInterval,
                targetTimeSpan: targetTimespan,
                maxTargetBits: Kit.maxTargetBits,
                powDGWHeight: 4002
            ))
        }

        blockValidatorSet.add(blockValidator: blockValidatorChain)

        let bitcoinCore = try BitcoinCoreBuilder(logger: logger)
            .set(network: network)
            .set(extendedKey: extendedKey)
            .set(watchAddressPublicKey: watchAddressPublicKey)
            .set(apiTransactionProvider: apiTransactionProvider)
            .set(checkpoint: Checkpoint.resolveCheckpoint(network: network, syncMode: syncMode, storage: storage))
            .set(apiSyncStateManager: apiSyncStateManager)
            .set(paymentAddressParser: paymentAddressParser)
            .set(walletID: walletID)
            .set(confirmationsThreshold: confirmationsThreshold)
            .set(peerSize: 10)
            .set(storage: storage)
            .set(syncMode: syncMode)
            .set(blockHeaderHasher: x11Hasher)
            .set(transactionInfoConverter: dashTransactionInfoConverter)
            .set(blockValidator: blockValidatorSet)
            .set(purpose: .bip44)
            .build()
        super.init(bitcoinCore: bitcoinCore, network: network)
        bitcoinCore.delegate = self

        // extending BitcoinCore

        let masternodeParser = MasternodeParser(hasher: singleHasher)
        let quorumParser = QuorumParser(hasher: doubleShaHasher)

        bitcoinCore.add(messageParser: TransactionLockMessageParser())
            .add(messageParser: TransactionLockVoteMessageParser())
            .add(messageParser: MasternodeListDiffMessageParser(
                masternodeParser: masternodeParser,
                quorumParser: quorumParser
            ))
            .add(messageParser: ISLockParser(hasher: doubleShaHasher))
            .add(messageParser: TransactionMessageParser(hasher: doubleShaHasher))

        bitcoinCore.add(messageSerializer: GetMasternodeListDiffMessageSerializer())

        let merkleBranch = MerkleBranch(hasher: doubleShaHasher)

        let masternodeSerializer = MasternodeSerializer()
        let coinbaseTransactionSerializer = CoinbaseTransactionSerializer()
        let masternodeCbTxHasher = MasternodeCbTxHasher(
            coinbaseTransactionSerializer: coinbaseTransactionSerializer,
            hasher: doubleShaHasher
        )

        let masternodeMerkleRootCreator = MerkleRootCreator(hasher: doubleShaHasher)
        let quorumMerkleRootCreator = MerkleRootCreator(hasher: doubleShaHasher)

        let masternodeListMerkleRootCalculator = MasternodeListMerkleRootCalculator(
            masternodeSerializer: masternodeSerializer,
            masternodeHasher: doubleShaHasher,
            masternodeMerkleRootCreator: masternodeMerkleRootCreator
        )
        let quorumListMerkleRootCalculator = QuorumListMerkleRootCalculator(
            merkleRootCreator: quorumMerkleRootCreator,
            quorumHasher: doubleShaHasher
        )
        let quorumListManager = QuorumListManager(
            storage: storage,
            hasher: doubleShaHasher,
            quorumListMerkleRootCalculator: quorumListMerkleRootCalculator,
            merkleBranch: merkleBranch
        )
        let masternodeListManager = MasternodeListManager(
            storage: storage,
            quorumListManager: quorumListManager,
            masternodeListMerkleRootCalculator: masternodeListMerkleRootCalculator,
            masternodeCbTxHasher: masternodeCbTxHasher,
            merkleBranch: merkleBranch
        )
        let masternodeSyncer = MasternodeListSyncer(
            bitcoinCore: bitcoinCore,
            initialBlockDownload: bitcoinCore.initialDownload,
            peerTaskFactory: PeerTaskFactory(),
            masternodeListManager: masternodeListManager
        )

        bitcoinCore.add(peerTaskHandler: masternodeSyncer)

        masternodeSyncer.subscribeTo(publisher: bitcoinCore.initialDownload.publisher)
        masternodeSyncer.subscribeTo(publisher: bitcoinCore.peerGroup.publisher)

        self.masternodeSyncer = masternodeSyncer

        let calculator = TransactionSizeCalculator()
        let confirmedUnspentOutputProvider = ConfirmedUnspentOutputProvider(
            storage: storage,
            confirmationsThreshold: confirmationsThreshold
        )
        let dustCalculator = DustCalculator(dustRelayTxFee: network.dustRelayTxFee, sizeCalculator: calculator)

        bitcoinCore.prepend(unspentOutputSelector: UnspentOutputSelector(
            calculator: calculator,
            provider: confirmedUnspentOutputProvider,
            dustCalculator: dustCalculator
        ))
        bitcoinCore.prepend(unspentOutputSelector: UnspentOutputSelectorSingleNoChange(
            calculator: calculator,
            provider: confirmedUnspentOutputProvider,
            dustCalculator: dustCalculator
        ))
        // --------------------------------------
        let transactionLockVoteValidator = TransactionLockVoteValidator(storage: storage, hasher: singleHasher)
        let instantSendLockValidator = InstantSendLockValidator(
            quorumListManager: quorumListManager,
            hasher: doubleShaHasher
        )

        let instantTransactionSyncer = InstantTransactionSyncer(transactionSyncer: bitcoinCore.transactionSyncer)
        let lockVoteManager = TransactionLockVoteManager(transactionLockVoteValidator: transactionLockVoteValidator)
        let instantSendLockManager = InstantSendLockManager(instantSendLockValidator: instantSendLockValidator)

        let instantSendLockHandler = InstantSendLockHandler(
            instantTransactionManager: instantTransactionManager,
            instantSendLockManager: instantSendLockManager,
            logger: logger
        )
        instantSendLockHandler.delegate = self
        let transactionLockVoteHandler = TransactionLockVoteHandler(
            instantTransactionManager: instantTransactionManager,
            lockVoteManager: lockVoteManager,
            logger: logger
        )
        transactionLockVoteHandler.delegate = self

        let instantSend = InstantSend(
            transactionSyncer: instantTransactionSyncer,
            transactionLockVoteHandler: transactionLockVoteHandler,
            instantSendLockHandler: instantSendLockHandler,
            logger: logger
        )
        self.instantSend = instantSend

        bitcoinCore.add(peerTaskHandler: instantSend)
        bitcoinCore.add(inventoryItemsHandler: instantSend)
        // --------------------------------------
        let base58AddressConverter = Base58AddressConverter(
            addressVersion: network.pubKeyHash,
            addressScriptVersion: network.scriptHash
        )
        bitcoinCore.add(restoreKeyConverter: Bip44RestoreKeyConverter(addressConverter: base58AddressConverter))
    }

    // MARK: Overridden Functions

    override public func transaction(hash: String) -> DashTransactionInfo? {
        super.transaction(hash: hash) as? DashTransactionInfo
    }

    // MARK: Functions

    public func transactions(
        fromUid: String? = nil,
        type: TransactionFilterType?,
        limit: Int? = nil
    )
        -> [DashTransactionInfo] {
        cast(transactionInfos: super.transactions(fromUid: fromUid, type: type, limit: limit))
    }

    private func cast(transactionInfos: [TransactionInfo]) -> [DashTransactionInfo] {
        transactionInfos.compactMap { $0 as? DashTransactionInfo }
    }
}

// MARK: BitcoinCoreDelegate

extension Kit: BitcoinCoreDelegate {
    public func transactionsUpdated(inserted: [TransactionInfo], updated: [TransactionInfo]) {
        // check for all new transactions if it's has instant lock
        for item in inserted.compactMap(\.transactionHash.sw.hexData) {
            instantSend?.handle(insertedTxHash: item)
        }

        delegate?.transactionsUpdated(
            inserted: cast(transactionInfos: inserted),
            updated: cast(transactionInfos: updated)
        )
    }

    public func transactionsDeleted(hashes: [String]) {
        delegate?.transactionsDeleted(hashes: hashes)
    }

    public func balanceUpdated(balance: BalanceInfo) {
        delegate?.balanceUpdated(balance: balance)
    }

    public func lastBlockInfoUpdated(lastBlockInfo: BlockInfo) {
        delegate?.lastBlockInfoUpdated(lastBlockInfo: lastBlockInfo)
    }

    public func kitStateUpdated(state: BitcoinCore.KitState) {
        delegate?.kitStateUpdated(state: state)
    }
}

// MARK: IInstantTransactionDelegate

extension Kit: IInstantTransactionDelegate {
    public func onUpdateInstant(transactionHash: Data) {
        guard let transaction = storage.transactionFullInfo(byHash: transactionHash) else {
            return
        }
        let transactionInfo = dashTransactionInfoConverter.transactionInfo(fromTransaction: transaction)
        bitcoinCore.delegateQueue.async { [weak self] in
            if let kit = self {
                kit.delegate?.transactionsUpdated(inserted: [], updated: kit.cast(transactionInfos: [transactionInfo]))
            }
        }
    }
}

extension Kit {
    public static func clear(exceptFor walletIDsToExclude: [String] = []) throws {
        try DirectoryHelper.removeAll(inDirectory: Kit.name, except: walletIDsToExclude)
    }

    private static func databaseFileName(
        walletID: String,
        networkType: NetworkType,
        syncMode: BitcoinCore.SyncMode
    )
        -> String {
        "\(walletID)-\(networkType.rawValue)-\(syncMode)"
    }
    
    private static func addressConverter(network: INetwork) -> AddressConverterChain {
        let addressConverter = AddressConverterChain()
        addressConverter.prepend(addressConverter: Base58AddressConverter(
            addressVersion: network.pubKeyHash,
            addressScriptVersion: network.scriptHash
        ))

        return addressConverter
    }

    public static func firstAddress(seed: Data, networkType: NetworkType) throws -> Address {
        let network = networkType.network

        return try BitcoinCore.firstAddress(
            seed: seed,
            purpose: Purpose.bip44,
            network: network,
            addressCoverter: addressConverter(network: network)
        )
    }
    
    public static func firstAddress(extendedKey: HDExtendedKey, networkType: NetworkType) throws -> Address {
        let network = networkType.network
        
        return try BitcoinCore.firstAddress(
            extendedKey: extendedKey,
            purpose: Purpose.bip44,
            network: network,
            addressCoverter: addressConverter(network: network)
        )
    }
}
