//
//  AccessoryChannel.swift
//  ue-roll-control
//
//  Created by Stephen Panaro on 9/27/19.
//  Copyright © 2019 Stephen Panaro. All rights reserved.
//

import Foundation
import ExternalAccessory

protocol AccessoryChannelDelegate {
    func didReceive(data: Data)
}

class AccessoryChannel: NSObject {

    let session: EASession
    private var delegate: AccessoryChannelDelegate?

    private let queue: DispatchQueue

    private var isConfigured: Bool = false
    private var writeBuffer = Data(capacity: 0)

    init(session: EASession, delegate: AccessoryChannelDelegate) {
        self.session = session
        self.queue = DispatchQueue(label: "com.hedgemereapps.accessory-channel-queue", qos: .default, attributes: [], autoreleaseFrequency: .inherit, target: nil)
        self.delegate = delegate
        super.init()
    }

    func write(data: Data) {
        configureIfNeeded()
        queue.async { [weak self] in
            self?.writeBuffer.append(data)
            self?.handleWrite()
        }
    }

    private func handleRead() {
        guard let input = session.inputStream else { return }

        var buffer = Data(capacity: 0)

//        print("handling read, has bytes: \(input.hasBytesAvailable)")
        while input.hasBytesAvailable {
            do {
                try buffer.append(input.read(maxLength: 100))
            }
            catch {
                print("Error reading bytes.")
                break
            }
        }

//        print("received \(buffer.count) bytes: \(buffer.hexEncodedString())")
        delegate?.didReceive(data: buffer)
    }

    private func handleWrite() {
        guard let output = session.outputStream else { return }

//        print("handling write, ouput has space: \(output.hasSpaceAvailable), buffer size: \(writeBuffer.count)")
        while output.hasSpaceAvailable && writeBuffer.count > 0 {
            do {
                let bytesWritten = try output.write(data: writeBuffer)
                writeBuffer.removeSubrange(0..<bytesWritten)
            }
            catch {
                print("Error writing data.")
                break
            }
        }
    }


    fileprivate func configureIfNeeded() {
        if (isConfigured) {
            return
        }

        session.inputStream?.delegate = self
        // TODO: Is using the main runloop bad?
        session.inputStream?.schedule(in: .main, forMode: .default)
        session.inputStream?.open()

        session.outputStream?.delegate = self
        session.outputStream?.schedule(in: .main, forMode: .default)
        session.outputStream?.open()

        isConfigured = true
    }

    deinit {
        close()
    }

    func close() {
        if (!isConfigured) {
            return
        }

        session.inputStream?.close()
        session.inputStream?.remove(from: .current, forMode: .default)

        session.outputStream?.close()
        session.outputStream?.remove(from: .current, forMode: .default)
    }
}

extension AccessoryChannel: StreamDelegate {
   public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
//        print("got event: \(eventCode.toString())")
        switch eventCode {
        case .hasBytesAvailable:
            queue.async { [weak self] in self?.handleRead() }
            break
        case .hasSpaceAvailable:
            queue.async { [weak self] in self?.handleWrite() }
            break
        default:
            break
        }
    }
}

extension Stream.Event {
    func toString() -> String {
        switch self {
        case .endEncountered: return "endEncountered"
        case .errorOccurred: return "errorOccurred"
        case .hasBytesAvailable: return "hasBytesAvailable"
        case .hasSpaceAvailable: return "hasSpaceAvailable"
        case .openCompleted: return "openCompleted"
        default:
            return "unknown"
        }
    }
}

// https://forums.developer.apple.com/thread/116309
extension InputStream {

    func read(buffer: UnsafeMutableRawBufferPointer) throws -> Int {
        // This check ensures that `baseAddress` will never be `nil`.
        guard !buffer.isEmpty else { return 0 }
        let bytesRead = self.read(buffer.baseAddress!.assumingMemoryBound(to: UInt8.self), maxLength: buffer.count)
        if bytesRead < 0 {
            throw self.guaranteedStreamError
        }
        return bytesRead
    }

    func read(maxLength: Int) throws -> Data {
        precondition(maxLength >= 0)
        var data = Data(repeating: 0, count: maxLength)
        let bytesRead = try data.withUnsafeMutableBytes { buffer -> Int in
            try self.read(buffer: buffer)
        }
        data.count = bytesRead
        return data
    }
}

extension OutputStream {

    func write(buffer: UnsafeRawBufferPointer) throws -> Int {
        // This check ensures that `baseAddress` will never be `nil`.
        guard !buffer.isEmpty else { return 0 }
        let bytesWritten = self.write(buffer.baseAddress!.assumingMemoryBound(to: UInt8.self), maxLength: buffer.count)
        if bytesWritten < 0 {
            throw self.guaranteedStreamError
        }
        return bytesWritten
    }

    func write(data: Data) throws -> Int {
        return try data.withUnsafeBytes { buffer -> Int in
            try self.write(buffer: buffer)
        }
    }
}

extension Stream {
    var guaranteedStreamError: Error {
        if let error = self.streamError {
            return error
        }
        // If this fires, the stream read or write indicated an error but the
        // stream didn’t record that error.  This is definitely a bug in the
        // stream implementation, and we want to know about it in our Debug
        // build. However, there’s no reason to crash the entire process in a
        // Release build, so in that case we just return a dummy error.
        assert(false)
        return NSError(domain: NSPOSIXErrorDomain, code: Int(ENOTTY), userInfo: nil)
    }
}
