//
//  MQTTClient.swift
//  MQTTKit
//
//  Created by Arne Christian Skarpnes on 30.03.2018.
//  Copyright © 2018 Arne Christian Skarpnes. All rights reserved.
//

import Foundation
//import CornucopiaStreams
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NIO
import WebSocketKit
  
final public class MQTTSession: NSObject, StreamDelegate {
    private var options: MQTTOptions
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private lazy var lastServerResponse: Date = Date()
    private var writeQueue = DispatchQueue(label: "mqtt_write")
    private var messageId: UInt16 = 0
    private var pendingPackets: [UInt16: MQTTPacket] = [:]
    
    private var keepAliveTimer: Timer?
    private var autoReconnectTimer: Timer?
    
    // MARK: - Delegate Callback Closures
    public var didRecieveMessage: ((_ message: MQTTMessage) -> Void)?
    public var didRecieveConack: ((_ status: MQTTConnackResponse) -> Void)?
    public var didSubscribe: ((_ topics: [String]) -> Void)?
    public var didUnsubscribe: ((_ topics: [String]) -> Void)?
    public var didConnect: ((_ connected: Bool) -> Void)?
    public var didDisconnect: ((_ error: Error?) -> Void)?
    public var didChangeState: ((_ state: MQTTConnectionState) -> Void)?

    // MARK: - Public interface
    public weak var delegate: MQTTSessionDelegate?
    public private(set) var state: MQTTConnectionState = .disconnected {
        didSet {
            guard state != oldValue else {
                return
            }
            switch state {
            case .connected:
                didConnect?(true)
            case .disconnected:
                didDisconnect?(nil)
            default:
                break
            }
            
            didChangeState?(state)
            delegate?.mqttSession(self, didChangeState: state)
        }
    }

    public init(host: String, port: Int = -1) {
        self.options = MQTTOptions(host: host)
        if port > 0 {
            self.options.port = port
        }
    }

    public init(options: MQTTOptions) {
        self.options = options
    }

    deinit {
        disconnect()
    }

    public func connect(completion: ((_ success: Bool) -> Void)? = nil) {
        closeStreams()
        openStreams { [weak self] streams in
            guard let strongSelf = self, let streams = streams else {
                completion?(false)
                return
            }

            strongSelf.inputStream = streams.input
            strongSelf.outputStream = streams.output

            strongSelf.mqttConnect()
            strongSelf.startKeepAliveTimer()

            strongSelf.messageId = 0x00

            completion?(true)
        }
    }

    public func disconnect() {
        autoReconnectTimer?.invalidate()
        keepAliveTimer?.invalidate()
        mqttDisconnect()
        closeStreams()
    }

    public func subscribe(to topic: String, qos: MQTTQoSLevel = .qos2) {
        subscribe(to: [topic: qos])
    }
    
    public func subscribe(to topics: [String]) {
        var topicQoS = [String: MQTTQoSLevel]()
        for topic in topics {
            topicQoS[topic] = .qos2
        }
        subscribe(to: topicQoS)
    }
    
    public func subscribe(to topics: [String: MQTTQoSLevel]) {
        mqttSubscribe(to: topics)
    }

    public func unsubscribe(from topic: String) {
        mqttUnsubscribe(from: [topic])
    }

    public func unsubscribe(from topics: [String]) {
        mqttUnsubscribe(from: topics)
    }

    public func publish(message: MQTTMessage) {
        mqttPublish(message: message)
    }

    public func publish(to topic: String, payload: Data, qos: MQTTQoSLevel = .qos0, retained: Bool = false) {
        let message = MQTTMessage(topic: topic, payload: payload, qos: qos, retained: retained)
        mqttPublish(message: message)
    }

    // MARK: - Keep alive timer

    private func startKeepAliveTimer() {
        keepAliveTimer?.invalidate()
        guard options.keepAliveInterval > 0 else {
            return
        }
        
        DispatchQueue.main.async { 
          if #available(macOS 10.12, *) {
            self.keepAliveTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.options.keepAliveInterval / 2), repeats: true, block: { [weak self] timer in
              guard self?.outputStream?.streamStatus == .open,
                    -self!.lastServerResponse.timeIntervalSinceNow < Double(self!.options.keepAliveInterval) * 1.5  else {
                timer.invalidate()
                self?.state = .disconnected
                self?.autoReconnect()
                return
              }
              
              self?.mqttPingreq()
            })
          } else {
            // Fallback on earlier versions
          }
        }
    }

    private func autoReconnect() {
        autoReconnectTimer?.invalidate()
        guard self.options.autoReconnect else {
            self.closeStreams()
            return
        }
        
        DispatchQueue.main.async {
          if #available(macOS 10.12, *) {
            self.autoReconnectTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.options.keepAliveInterval / 2), repeats: true, block: { [lsr = self.lastServerResponse, timeout = self.options.autoReconnectTimeout] timer in
              guard -lsr.timeIntervalSinceNow < timeout && self.state == .disconnected else {
                timer.invalidate()
                return
              }
              self.connect()
            })
          } else {
            // Fallback on earlier versions
          }
        }
    }
  
  var websocket: WebSocketClient?
  var eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)

    // MARK: - Socket connection
    private func openStreams(completion: @escaping (((input: InputStream, output: OutputStream)?) -> Void)) {

        guard let host = options.host else { completion(nil); return }
//        var inputStream: InputStream?
//        var outputStream: OutputStream?
      
//      //https://medium.com/flawless-app-stories/different-flavors-of-websockets-on-vapor-with-swift-54ce00cc60b4
//      let promise = eventLoopGroup.next().makePromise(of: String.self)
//      WebSocket.connect(to: "wss://\(host):\(options.port)", on: eventLoopGroup) { ws in
//        print("socket was upgraded \(ws)")
//
//      }.cascadeFailure(to: promise)
      
//      WebSocket.connect(to: "wss://\(host):\(options.port)", on: eventLoopGroup) { websocket in
//        print("websocket upgraded \(websocket)")
//        
//      }.whenFailure() { error in
//        print(error.localizedDescription)
//      }
      

      
        
//        websocket = WebSocketClient(eventLoopGroupProvider: .createNew)
//      let promise = websocket?.connect(scheme: "wss", host: host, port: options.port) { socket in
//        print("websocket connect completion:  \(socket)")
//      }
//      do {
//        try promise?.wait()
//      } catch {
//        print("caught error on promise wait")
//      }
        
//      #if os(Linux)
//      guard let url = URL(string: "tcp://\(host):\(options.port)") else { completion(nil); return }
        print("About to get the streams")
      
//        let streams = Stream.CC_getStreamsToHost(with: host, port: options.port)
//        inputStream = streams.0
//        outputStream = streams.1

//        Stream.getStreamsToHost(
//          withName: options.host,
//          port: options.port,
//          inputStream: &inputStream,
//          outputStream: &outputStream)
      
      guard let input = inputStream, let output = outputStream else {
          completion(nil)
          return
      }
      
//      Stream.CC_getStreamPair(to: url, timeout: 3.0) { result in
//        switch result {
//        case .success(let (input, output)):
        input.delegate = self
        output.delegate = self
        input.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
        output.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
        if self.options.useTLS {
            _ = input.setProperty(StreamSocketSecurityLevel.tlSv1.rawValue as AnyObject?, forKey: .socketSecurityLevelKey)
            _ = output.setProperty(StreamSocketSecurityLevel.tlSv1.rawValue as AnyObject?, forKey: .socketSecurityLevelKey)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            input.open()
            output.open()

            while input.streamStatus == .opening || output.streamStatus == .opening {
                usleep(1000)
            }

            if input.streamStatus != .open || output.streamStatus != .open {
                completion(nil)
                return
            }
            completion((input, output))
        }
        
//        case .failure(let a):
//          print ("GetStreamPair fails:  \(a)")
//        }
//      }
//      #else
//        Stream.getStreamsToHost(
//          withName: options.host,
//          port: options.port,
//          inputStream: &inputStream,
//          outputStream: &outputStream)
//      #endif


//        guard let input = inputStream, let output = outputStream else {
//            completion(nil)
//            return
//        }
//
//        input.delegate = self
//        output.delegate = self
//
//        input.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
//        output.schedule(in: RunLoop.main, forMode: RunLoop.Mode.default)
//
//        if options.useTLS {
//            _ = input.setProperty(StreamSocketSecurityLevel.tlSv1.rawValue as AnyObject?, forKey: .socketSecurityLevelKey)
//            _ = output.setProperty(StreamSocketSecurityLevel.tlSv1.rawValue as AnyObject?, forKey: .socketSecurityLevelKey)
//        }
//
//        DispatchQueue.global(qos: .userInitiated).async {
//            input.open()
//            output.open()
//
//            while input.streamStatus == .opening || output.streamStatus == .opening {
//                usleep(1000)
//            }
//
//            if input.streamStatus != .open || output.streamStatus != .open {
//                completion(nil)
//                return
//            }
//
//            completion((input, output))
//        }
    }

    internal func closeStreams() {
        inputStream?.close()
        outputStream?.close()

        inputStream = nil
        outputStream = nil
    }

    // MARK: - Stream Delegate
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
          print("stream delegate has bytes availabe")
          if let input = aStream as? InputStream {
            print("aStream is an input stream, commence reading the packet")
                readStream(input: input)
            }
        case .errorOccurred:
            //options.autoReconnect ? autoReconnect() : disconnect()
            break
        default:
            break
        }
    }
  
  private func processHeader(messageBuffer: UnsafeMutablePointer<UInt8>, length: Int) {
    
  }

    // MARK: - Stream reading
    private func readStream(input: InputStream) {
        var packet: MQTTPacket!
        let messageBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: options.bufferSize)
        defer {
            messageBuffer.deinitialize(count: options.bufferSize)
            messageBuffer.deallocate()
        }
      print("Do the full read")
      var timsbytesRead: Int = 0
      
//      let count = input.read(messageBuffer, maxLength: options.bufferSize)
//      timsbytesRead += count
    

    
//    print("In reading outer loop and read:  \(count) bytes, \(timsbytesRead) total")
//    let realBuffer = UnsafeMutableBufferPointer(start: messageBuffer, count:100)
//    print("Printing the buffer")
//    for i in 0..<timsbytesRead {
//      print("\(i):  \(String(format: "%02X", realBuffer[i]))")
//    }
      

      print("entering outer loop")
        mainReading: while input.streamStatus == .open && input.hasBytesAvailable {
            // Header
//          print("stream is \(input.streamStatus) has bytes:  \(input.hasBytesAvailable)")
//            guard let data = try? (input as? FileHandleInputStream)?.fileHandle.read(upToCount: 1) else { continue }
//            let count = data.count
            let count = input.read(messageBuffer, maxLength: options.bufferSize)
            timsbytesRead += count
          
          
          print("In reading outer loop and read:  \(count) bytes, \(timsbytesRead) total")
          let realBuffer = UnsafeMutableBufferPointer(start: messageBuffer, count:100)
          print("Printing the buffer")
          for i in 0..<timsbytesRead {
            print("\(i):  \(String(format: "%02X", realBuffer[i]))")
          }
            if count == 0 {
                continue
            } else if count < 0 {
                break
            }

            if let _ = MQTTPacket.PacketType(rawValue: messageBuffer.pointee & MQTTPacket.Header.typeMask) {
                packet = MQTTPacket(header: messageBuffer.pointee)
            } else {
                // Not valid header
                continue
            }

            // Remaining Length
            var multiplier = 1
            var remainingLength = 0
          
            print("entering inner loop")  // I think this is computing the size of the payload
            repeat {
                let count = input.read(messageBuffer, maxLength: 1)
                timsbytesRead += count
                print("In reading outer loop and read:  \(count) bytes, \(timsbytesRead) total")
                print("\(String(format: "%02X", messageBuffer.pointee))")
                if count == 0 {
                    continue mainReading
                } else if count < 0 {
                    break mainReading
                }

                remainingLength += Int(messageBuffer.pointee & 127) * multiplier
                multiplier *= 128

                if multiplier > 2_097_152 { // 128 * 128 * 128 MAX LENGTH
                    // Error?
                    break mainReading
                }
            } while messageBuffer.pointee & 128 != 0

            // Variable header //

            if packet.type == .connack {
                // Connack response code
                let count = input.read(messageBuffer, maxLength: 2)
                timsbytesRead += count
                print("In connack and read:  \(count) bytes, \(timsbytesRead) total")
                if count == 0 {
                    continue
                } else if count < 0 {
                    return
                }
                remainingLength -= count
                packet.variableHeader.append(messageBuffer, count: count)
            }

            if packet.type == .publish {
                // Topic length
                var count = input.read(messageBuffer, maxLength: 2)
              timsbytesRead += count
              print("In publish and read:  \(count) bytes, \(timsbytesRead) total")
                if count == 0 {
                    continue
                } else if count < 0 {
                    return
                }

                let msb = messageBuffer[0], lsb = messageBuffer[1]
                let topicLength = Int((UInt16(msb) << 8) + UInt16(lsb))
                remainingLength -= count

                // Topic
                count = input.read(messageBuffer, maxLength: topicLength)
                if count == 0 {
                    continue
                } else if count < 0 {
                    return
                }

                remainingLength -= count
                packet.topic = String(bytesNoCopy: messageBuffer, length: topicLength, encoding: .utf8, freeWhenDone: false)
            }

            if packet.type.rawValue + packet.qos.rawValue >= (MQTTPacket.Header.publish + MQTTQoSLevel.qos1.rawValue) && packet.type.rawValue <= MQTTPacket.Header.unsuback {

                let count = input.read(messageBuffer, maxLength: 2)
                if count == 0 {
                    continue
                } else if count < 0 {
                    return
                }
                remainingLength -= count

                let msb = messageBuffer[0], lsb = messageBuffer[1]
                let id = (UInt16(msb) << 8) + UInt16(lsb)

                packet.identifier = id
            }

            /*  Payload
             ..
             PUBLISH: Optional
             SUBACK: Required
             */

            var bytesRead = 0
            while remainingLength > 0 {
                let count = input.read(messageBuffer, maxLength: min(remainingLength, options.bufferSize))
                if count == 0 {
                    continue mainReading
                } else if count < 0 {
                    return
                }
                bytesRead += count
                remainingLength -= count

                // Append data
                let data = Data(bytes: messageBuffer, count: count)
                packet.payload.append(data)
            }
            print("Handling the packet")
            handlePacket(packet)
        }
    }

    private func handlePacket(_ packet: MQTTPacket) {

        lastServerResponse = Date()

         //print("\t\t<-", packet.type, packet.identifier ?? "")

        switch packet.type {
        case .connack:
            if let res = packet.connectionResponse {
                if res == .accepted {
                    state = .connected
                }
                didRecieveConack?(res)
                delegate?.mqttSession(self, didRecieveConnack: res)
                autoReconnectTimer?.invalidate()
            }

        case .publish:
            var duplicate = false
            if let id = packet.identifier {
                switch packet.qos {
                case .qos1:
                    mqttPuback(id: id)
                    pendingPackets.removeValue(forKey: id)
                case .qos2:
                    if let pending = pendingPackets[id], pending.type == .pubrec {
                        duplicate = true
                    }
                    mqttPubrec(id: id)
                default:
                    break
                }
            }
            if !duplicate, let msg = MQTTMessage(packet: packet) {
                didRecieveMessage?(msg)
                delegate?.mqttSession(self, didRecieveMessage: msg)
            }
        case .puback:
            break
        case .pubrec:
            if let id = packet.identifier {
                mqttPubrel(id: id)
            }
        case .pubcomp:
            if let id = packet.identifier {
                pendingPackets.removeValue(forKey: id)
            }
        case .pubrel:
            if let id = packet.identifier {
                mqttPubcomp(id: id)
                pendingPackets.removeValue(forKey: id)
            }
        case .suback:
            if let id = packet.identifier, pendingPackets[id]?.type == .subscribe, let topics = pendingPackets[id]?.topics, let maxQoS = packet.maxQoS {
                pendingPackets.removeValue(forKey: id)
                didSubscribe?(topics)
                delegate?.mqttSession(self, didSubscribeToTopics: topics, withMaxQoSLevel: maxQoS)
            }
        case .unsuback:
            if let id = packet.identifier, pendingPackets[id]?.type == .unsubscribe, let topics = pendingPackets[id]?.topics  {
                pendingPackets.removeValue(forKey: id)
                didUnsubscribe?(topics)
                delegate?.mqttSession(self, didUnsubscribeToTopics: topics)
            }
        case .pingresp:
            handlePendingPackets()

        case .disconnect:
            state = .disconnected

        default:
            print("Unhandled packet -", packet.type)
            break
        }
    }

    private func handlePendingPackets() {
        for var packet in pendingPackets.values {
            if packet.type == .publish {
                packet.dup = true
            }
            send(packet: packet)
        }
    }

    // MARK: - MQTT messages

    private func mqttConnect() {
        var connFlags: UInt8 = 0
        var packet = MQTTPacket(header: MQTTPacket.Header.connect)
        packet.payload += options.clientId

        if options.cleanSession {
            connFlags |= MQTTPacket.Connect.cleanSession
        }

        if let will = options.will {
            connFlags |= MQTTPacket.Connect.will
            packet.payload += will.topic
            packet.payload += will.string ?? ""
            connFlags |= will.qos.rawValue << 2
        }

        if let username = options.username {
            connFlags |= MQTTPacket.Connect.username
            packet.payload += username
        }

        if let password = options.password {
            connFlags |= MQTTPacket.Connect.password
            packet.payload += password
        }

        packet.variableHeader += MQTTProtocol.Name
        packet.variableHeader += MQTTProtocol.Level
        packet.variableHeader += connFlags
        packet.variableHeader += options.keepAliveInterval
      
        send(packet: packet)
    }

    private func mqttDisconnect() {

        let packet = MQTTPacket(header: MQTTPacket.Header.disconnect)
        send(packet: packet)
        self.state = .disconnected
    }

    private func mqttSubscribe(to topics: [String: MQTTQoSLevel]) {

        var packet = MQTTPacket(header: MQTTPacket.Header.subscribe)
        let id = nextMessageId()
        packet.identifier = id
        packet.variableHeader += id

        for (topic, qos) in topics {
            packet.payload += topic
            packet.payload += qos.rawValue >> 1
        }
        send(packet: packet)
    }

    private func mqttUnsubscribe(from topics: [String]) {

        var packet = MQTTPacket(header: MQTTPacket.Header.unsubscribe)
        let id = nextMessageId()
        packet.identifier = id
        packet.variableHeader += id
        for topic in topics {
            packet.payload += topic
        }

        send(packet: packet)
    }

    private func mqttPublish(message: MQTTMessage) {

        var packet = MQTTPacket(header: message.header)
        packet.variableHeader += message.topic
        if message.qos > .qos0 {
            let id = nextMessageId()
            packet.identifier = id
            packet.variableHeader += id
        }
        packet.payload = message.payload
        
        send(packet: packet)
    }

    private func mqttPingreq() {
        let packet = MQTTPacket(header: MQTTPacket.Header.pingreq)
        send(packet: packet)
    }

    // MARK: - QoS 1 Reciever

    private func mqttPuback(id: UInt16) {
        var packet = MQTTPacket(header: MQTTPacket.Header.puback)
        packet.variableHeader += id
        packet.identifier = id
        send(packet: packet)
    }

    // MARK: - QoS 2 Sender

    private func mqttPubrel(id: UInt16) {
        var packet = MQTTPacket(header: MQTTPacket.Header.pubrel)
        packet.variableHeader += id
        packet.identifier = id
        send(packet: packet)
    }

    // MARK: - QoS 2 Reciever

    private func mqttPubrec(id: UInt16) {
        var packet = MQTTPacket(header: MQTTPacket.Header.pubrec)
        packet.variableHeader += id
        packet.identifier = id
        send(packet: packet)
    }

    private func mqttPubcomp(id: UInt16) {
        var packet = MQTTPacket(header: MQTTPacket.Header.pubcomp)
        packet.variableHeader += id
        packet.identifier = id
        send(packet: packet)
    }

    // MARK: - Send Packet

    private func send(packet: MQTTPacket) {

        if let id = packet.identifier {
            pendingPackets[id] = packet
        }

        guard let output = outputStream else { return }
        // print(packet.type, packet.identifier ?? "", "->")

        let serialized = packet.encoded
        var toSend = serialized.count
        var sent = 0
        
        writeQueue.sync {
            while toSend > 0 {
                
              let count = serialized.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int in
                output.write(ptr.bindMemory(to: UInt8.self).baseAddress!.advanced(by: sent), maxLength: toSend)
              }
              
                if count < 0 {
                    return
                }
                toSend -= count
                sent += count
            }
        }
    }

    private func nextMessageId() -> UInt16 {
        messageId = messageId &+ 1
        return messageId
    }
}
