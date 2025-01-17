//
//  MasternodeListDiffMessageParser.swift
//
//  Created by Sun on 2019/3/18.
//

import Foundation

import BitcoinCore
import SWExtensions

class MasternodeListDiffMessageParser: IMessageParser {
    // MARK: Properties

    private let masternodeParser: IMasternodeParser
    private let quorumParser: IQuorumParser

    // MARK: Computed Properties

    var id: String { "mnlistdiff" }

    // MARK: Lifecycle

    init(masternodeParser: IMasternodeParser, quorumParser: IQuorumParser) {
        self.masternodeParser = masternodeParser
        self.quorumParser = quorumParser
    }

    // MARK: Functions

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

        let baseBlockHash = byteStream.read(Data.self, count: 32)
        let blockHash = byteStream.read(Data.self, count: 32)
        let totalTransactions = byteStream.read(UInt32.self)
        let merkleHashesCount = UInt32((byteStream.read(VarInt.self)).underlyingValue)

        var merkleHashes = [Data]()
        for _ in 0 ..< merkleHashesCount {
            merkleHashes.append(byteStream.read(Data.self, count: 32))
        }

        let merkleFlagsCount = UInt32((byteStream.read(VarInt.self)).underlyingValue)
        let merkleFlags = byteStream.read(Data.self, count: Int(merkleFlagsCount))
        let cbTx = CoinbaseTransaction(byteStream: byteStream)

        let nVersion = byteStream.read(UInt16.self)
        let deletedMNsCount = UInt32((byteStream.read(VarInt.self)).underlyingValue)
        var deletedMNs = [Data]()
        for _ in 0 ..< deletedMNsCount {
            deletedMNs.append(byteStream.read(Data.self, count: 32))
        }

        let mnListCount = UInt32((byteStream.read(VarInt.self)).underlyingValue)
        var mnList = [Masternode]()
        for _ in 0 ..< mnListCount {
            mnList.append(masternodeParser.parse(byteStream: byteStream))
        }

        let deletedQuorumsCount = Int(byteStream.read(VarInt.self).underlyingValue)
        var deletedQuorums = [(type: UInt8, quorumHash: Data)]()
        for _ in 0 ..< deletedQuorumsCount {
            deletedQuorums.append((
                type: byteStream.read(UInt8.self),
                quorumHash: byteStream.read(Data.self, count: 32)
            ))
        }

        let newQuorumsCount = Int(byteStream.read(VarInt.self).underlyingValue)
        var quorumList = [Quorum]()
        for _ in 0 ..< newQuorumsCount {
            quorumList.append(quorumParser.parse(byteStream: byteStream))
        }

        return MasternodeListDiffMessage(
            baseBlockHash: baseBlockHash,
            blockHash: blockHash,
            totalTransactions: totalTransactions,
            merkleHashesCount: merkleHashesCount,
            merkleHashes: merkleHashes,
            merkleFlagsCount: merkleFlagsCount,
            merkleFlags: merkleFlags,
            cbTx: cbTx,
            nVersion: nVersion,
            deletedMNsCount: deletedMNsCount,
            deletedMNs: deletedMNs,
            mnListCount: mnListCount,
            mnList: mnList,
            deletedQuorums: deletedQuorums,
            quorumList: quorumList
        )
    }
}
