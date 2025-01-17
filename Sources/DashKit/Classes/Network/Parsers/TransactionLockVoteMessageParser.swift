//
//  TransactionLockVoteMessageParser.swift
//
//  Created by Sun on 2019/3/18.
//

import Foundation

import BitcoinCore
import SWCryptoKit
import SWExtensions

class TransactionLockVoteMessageParser: IMessageParser {
    // MARK: Computed Properties

    var id: String { "txlvote" }

    // MARK: Functions

    func parse(data: Data) -> IMessage {
        let byteStream = ByteStream(data)

        let txHash = byteStream.read(Data.self, count: 32)
        let outpoint = Outpoint(byteStream: byteStream)
        let outpointMasternode = Outpoint(byteStream: byteStream)
        let quorumModifierHash = byteStream.read(Data.self, count: 32)
        let masternodeProTxHash = byteStream.read(Data.self, count: 32)
        let signatureLength = byteStream.read(VarInt.self)
        let vchMasternodeSignature = byteStream.read(Data.self, count: Int(signatureLength.underlyingValue))

        let hash = Crypto.doubleSha256(data.prefix(168))

        return TransactionLockVoteMessage(
            txHash: txHash,
            outpoint: outpoint,
            outpointMasternode: outpointMasternode,
            quorumModifierHash: quorumModifierHash,
            masternodeProTxHash: masternodeProTxHash,
            vchMasternodeSignature: vchMasternodeSignature,
            hash: hash
        )
    }
}
