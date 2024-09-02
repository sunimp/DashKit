//
//  Masternode.swift
//
//  Created by Sun on 2019/3/18.
//

import Foundation

import GRDB

// MARK: - Masternode

class Masternode: Record {
    // MARK: Nested Types

    enum Columns: String, ColumnExpression {
        case nVersion
        case proRegTxHash
        case confirmedHash
        case confirmedHashWithProRegTxHash
        case ipAddress
        case port
        case pubKeyOperator
        case keyIDVoting
        case isValid
        case type
        case platformHTTPPort
        case platformNodeID
    }

    // MARK: Overridden Properties

    override class var databaseTableName: String {
        "masternodes"
    }

    // MARK: Properties

    let nVersion: UInt16
    let proRegTxHash: Data
    let confirmedHash: Data
    var confirmedHashWithProRegTxHash: Data
    let ipAddress: Data
    let port: UInt16
    let pubKeyOperator: Data
    let keyIDVoting: Data
    let isValid: Bool
    let type: UInt16?
    let platformHTTPPort: UInt16?
    let platformNodeID: Data?

    // MARK: Lifecycle

    required init(row: Row) throws {
        nVersion = row[Columns.nVersion]
        proRegTxHash = row[Columns.proRegTxHash]
        confirmedHash = row[Columns.confirmedHash]
        confirmedHashWithProRegTxHash = row[Columns.confirmedHashWithProRegTxHash]
        ipAddress = row[Columns.ipAddress]
        port = row[Columns.port]
        pubKeyOperator = row[Columns.pubKeyOperator]
        keyIDVoting = row[Columns.keyIDVoting]
        isValid = row[Columns.isValid]
        type = row[Columns.type]
        platformHTTPPort = row[Columns.platformHTTPPort]
        platformNodeID = row[Columns.platformNodeID]

        try super.init(row: row)
    }

    init(
        nVersion: UInt16,
        proRegTxHash: Data,
        confirmedHash: Data,
        confirmedHashWithProRegTxHash: Data,
        ipAddress: Data,
        port: UInt16,
        pubKeyOperator: Data,
        keyIDVoting: Data,
        isValid: Bool,
        type: UInt16?,
        platformHTTPPort: UInt16?,
        platformNodeID: Data?
    ) {
        self.nVersion = nVersion
        self.proRegTxHash = proRegTxHash
        self.confirmedHash = confirmedHash
        self.confirmedHashWithProRegTxHash = confirmedHashWithProRegTxHash
        self.ipAddress = ipAddress
        self.port = port
        self.pubKeyOperator = pubKeyOperator
        self.keyIDVoting = keyIDVoting
        self.isValid = isValid
        self.type = type
        self.platformHTTPPort = platformHTTPPort
        self.platformNodeID = platformNodeID

        super.init()
    }

    // MARK: Overridden Functions

    override func encode(to container: inout PersistenceContainer) throws {
        container[Columns.nVersion] = nVersion
        container[Columns.proRegTxHash] = proRegTxHash
        container[Columns.confirmedHash] = confirmedHash
        container[Columns.confirmedHashWithProRegTxHash] = confirmedHashWithProRegTxHash
        container[Columns.ipAddress] = ipAddress
        container[Columns.port] = port
        container[Columns.pubKeyOperator] = pubKeyOperator
        container[Columns.keyIDVoting] = keyIDVoting
        container[Columns.isValid] = isValid
        container[Columns.type] = type
        container[Columns.platformHTTPPort] = platformHTTPPort
        container[Columns.platformNodeID] = platformNodeID
    }
}

// MARK: Hashable, Comparable

extension Masternode: Hashable, Comparable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(proRegTxHash)
    }

    public static func == (lhs: Masternode, rhs: Masternode) -> Bool {
        lhs.proRegTxHash == rhs.proRegTxHash
    }

    public static func < (lhs: Masternode, rhs: Masternode) -> Bool {
        lhs.proRegTxHash < rhs.proRegTxHash
    }
}
