import Foundation

public protocol Signaling {
    associatedtype Connect: Encodable
    /*
    associatedtype Offer: Decodable
    associatedtype Answer: Encodable
    associatedtype Candidate: Encodable
    associatedtype UpdateToServer: Encodable
    associatedtype UpdateToClient: Decodable
    associatedtype Push: Decodable
    associatedtype Notify: Decodable
     */
}

public enum SignalingSimulcast {
    case low
    case middle
    case high
}

/**
 "connect" シグナリングメッセージを表します。
 このメッセージはシグナリング接続の確立後、最初に送信されます。
 */
public struct SignalingConnect<ConnectMetadata: Encodable, NotifyMetadata: Encodable> {
    
    /// ロール
    public var role: SignalingRole
    
    /// チャネル ID
    public var channelId: String
    
    /// メタデータ
    public var metadata: ConnectMetadata?
    
    /// notify メタデータ
    public var notifyMetadata: NotifyMetadata?
    
    /// SDP 。クライアントの判別に使われます。
    public var sdp: String?
    
    /// マルチストリームの可否
    public var multistreamEnabled: Bool
    
    /// Plan B の可否
    public var planBEnabled: Bool
    
    /// スポットライト数
    public var spotlight: Int?
    
    /// サイマルキャスト
    public var simulcast: SignalingSimulcast?
    
    /// 映像の可否
    public var videoEnabled: Bool
    
    /// 映像コーデック
    public var videoCodec: VideoCodec
    
    /// 映像ビットレート
    public var videoBitRate: Int?
    
    /// 音声の可否
    public var audioEnabled: Bool
    
    /// 音声コーデック
    public var audioCodec: AudioCodec
    
    /// 最大話者数
    public var maxNumberOfSpeakers: Int?
    
}

// MARK: -
// MARK: Codable

private var simulcastTable: PairTable<String, SignalingSimulcast> =
    PairTable(name: "SignalingSimulcast",
              pairs: [("low", .low),
                      ("middle", .middle),
                      ("high", .high)])

/// :nodoc:
extension SignalingSimulcast: Encodable {
    
    public func encode(to encoder: Encoder) throws {
        try simulcastTable.encode(self, to: encoder)
    }
    
}

/// :nodoc:
extension SignalingConnect: Encodable {
    
    enum CodingKeys: String, CodingKey {
        case role
        case channel_id
        case metadata
        case signaling_notify_metadata
        case sdp
        case multistream
        case plan_b
        case spotlight
        case simulcast
        case video
        case audio
        case vad
    }
    
    enum VideoCodingKeys: String, CodingKey {
        case codec_type
        case bit_rate
    }
    
    enum AudioCodingKeys: String, CodingKey {
        case codec_type
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(channelId, forKey: .channel_id)
        
        if let sdp = sdp {
            try container.encode(sdp, forKey: .sdp)
        }
        
        if let metadata = metadata {
            try container.encode(metadata, forKey: .metadata)
        }
        
        if let notifyMetadata = notifyMetadata {
            try container.encode(notifyMetadata, forKey: .signaling_notify_metadata)
        }
        
        if multistreamEnabled {
            try container.encode(true, forKey: .multistream)
        }
        
        if planBEnabled {
            try container.encode(planBEnabled, forKey: .plan_b)
        }
        
        if videoEnabled {
            if videoCodec != .default || videoBitRate != nil {
                var videoContainer = container
                    .nestedContainer(keyedBy: VideoCodingKeys.self,
                                     forKey: .video)
                if videoCodec != .default {
                    try videoContainer.encode(videoCodec, forKey: .codec_type)
                }
                if let bitRate = videoBitRate {
                    try videoContainer.encode(bitRate, forKey: .bit_rate)
                }
            }
        } else {
            try container.encode(false, forKey: .video)
        }
        
        if audioEnabled {
            switch audioCodec {
            case .default:
                break
            default:
                var audioContainer = container
                    .nestedContainer(keyedBy: AudioCodingKeys.self, forKey: .audio)
                try audioContainer.encode(audioCodec, forKey: .codec_type)
            }
        } else {
            try container.encode(false, forKey: .audio)
        }
        
        if let num = maxNumberOfSpeakers {
            try container.encode(num, forKey: .vad)
        }
    }
    
}
