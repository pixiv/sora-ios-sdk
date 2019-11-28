import CoreMedia
import Foundation
import WebRTC

public class AudioDeviceModule {

    public static var `default`: AudioDeviceModule = AudioDeviceModule()

    var nativeModule: RTCAudioDeviceModule = RTCAudioDeviceModule()

    public var audioUnitSubType: OSType {
        get {
            return nativeModule.audioUnitSubType;
        }

        set(subType) {
            nativeModule.audioUnitSubType = subType;
        }
    }

    func deliverRecordedData(_ sampleBuffer: CMSampleBuffer) {
        nativeModule.deliverRecordedData(sampleBuffer)
    }
}
