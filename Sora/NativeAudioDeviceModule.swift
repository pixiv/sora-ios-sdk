import CoreMedia
import Foundation
import WebRTC

class NativeAudioDeviceModule {

    static var `default`: NativeAudioDeviceModule = NativeAudioDeviceModule()

    var nativeModule: RTCAudioDeviceModule = RTCAudioDeviceModule()

    func deliverRecordedData(_ sampleBuffer: CMSampleBuffer) {
        nativeModule.deliverRecordedData(sampleBuffer)
    }
}
