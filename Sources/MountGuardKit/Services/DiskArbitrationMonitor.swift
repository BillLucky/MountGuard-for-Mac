import DiskArbitration
import Foundation

public final class DiskArbitrationMonitor {
    public var onChange: (@Sendable () -> Void)?

    private let session: DASession

    public init?() {
        guard let session = DASessionCreate(kCFAllocatorDefault) else {
            return nil
        }

        self.session = session
        let context = Unmanaged.passUnretained(self).toOpaque()

        DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        DARegisterDiskAppearedCallback(session, nil, Self.diskDidChange, context)
        DARegisterDiskDisappearedCallback(session, nil, Self.diskDidChange, context)
    }

    private static let diskDidChange: DADiskAppearedCallback = { _, context in
        guard let context else { return }
        let monitor = Unmanaged<DiskArbitrationMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.onChange?()
    }
}
