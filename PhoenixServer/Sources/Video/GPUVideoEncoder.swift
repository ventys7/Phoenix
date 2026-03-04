import Foundation
import VideoToolbox
import CoreMedia

protocol GPUVideoEncoderDelegate: AnyObject {
    func encoder(_ encoder: GPUVideoEncoder, didEncodeFrame data: Data, isKeyframe: Bool)
}

private func compressionOutputCallback(refcon: UnsafeMutableRawPointer?, sourceFrameRefcon: UnsafeMutableRawPointer?, status: OSStatus, flags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) {
    guard status == noErr, let sampleBuffer = sampleBuffer else { return }
    let encoder = Unmanaged<GPUVideoEncoder>.fromOpaque(refcon!).takeUnretainedValue()
    encoder.handleEncodedFrame(sampleBuffer)
}

class GPUVideoEncoder {
    weak var delegate: GPUVideoEncoderDelegate?
    let width: Int
    let height: Int
    
    // Ripristinato per compatibilità con ServerManager
    var fps: Int = 30
    
    private var compressionSession: VTCompressionSession?
    private let annexBStartCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]
    
    init(width: Int = 1024, height: Int = 768) {
        self.width = width
        self.height = height
    }
    
    func start() throws {
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as CFDictionary,
            compressedDataAllocator: nil,
            outputCallback: compressionOutputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )
        
        guard status == noErr, let s = session else { return }
        self.compressionSession = s
        
        VTSessionSetProperty(s, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(s, key: kVTCompressionPropertyKey_H264EntropyMode, value: kVTH264EntropyMode_CAVLC)
        VTSessionSetProperty(s, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        
        // I-frame ravvicinati per KitKat (ogni 0.5s a 30fps)
        VTSessionSetProperty(s, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: 15 as CFNumber)
        
        let bitrate = 1200 * 1000
        VTSessionSetProperty(s, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)
        VTSessionSetProperty(s, key: kVTCompressionPropertyKey_DataRateLimits, value: [bitrate / 8, 1] as CFArray)
        VTSessionSetProperty(s, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        
        VTCompressionSessionPrepareToEncodeFrames(s)
    }

    func encodeFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard let s = compressionSession else { return }
        VTCompressionSessionEncodeFrame(s, imageBuffer: pixelBuffer, presentationTimeStamp: presentationTime, duration: .invalid, frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: nil)
    }

    // Ripristinato per compatibilità con ServerManager
    func stop() {
        if let s = compressionSession {
            VTCompressionSessionInvalidate(s)
        }
        compressionSession = nil
    }

    func handleEncodedFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer), let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let isKeyframe = checkIsKeyFrame(sampleBuffer: sampleBuffer)
        var fullData = Data()
        
        if isKeyframe {
            fullData.append(contentsOf: annexBStartCode)
            fullData.append(getParamSet(format, index: 0))
            fullData.append(contentsOf: annexBStartCode)
            fullData.append(getParamSet(format, index: 1))
        }

        var length = 0; var ptr: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &ptr)
        if let ptr = ptr {
            fullData.append(convertAVCCtoAnnexB(Data(bytes: ptr, count: length)))
            delegate?.encoder(self, didEncodeFrame: fullData, isKeyframe: isKeyframe)
        }
    }

    private func getParamSet(_ format: CMFormatDescription, index: Int) -> Data {
        var ptr: UnsafePointer<UInt8>?; var size = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, parameterSetIndex: index, parameterSetPointerOut: &ptr, parameterSetSizeOut: &size, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
        return (ptr != nil) ? Data(bytes: ptr!, count: size) : Data()
    }

    private func convertAVCCtoAnnexB(_ data: Data) -> Data {
        var result = Data(); var offset = 0
        while offset < data.count - 4 {
            let len = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
            result.append(contentsOf: annexBStartCode)
            let start = offset + 4
            if start + Int(len) <= data.count {
                result.append(data.subdata(in: start..<(start + Int(len))))
            }
            offset += 4 + Int(len)
        }
        return result
    }
    
    private func checkIsKeyFrame(sampleBuffer: CMSampleBuffer) -> Bool {
        let arr = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]]
        return !(arr?.first?[kCMSampleAttachmentKey_DependsOnOthers] as? Bool ?? true)
    }
}
