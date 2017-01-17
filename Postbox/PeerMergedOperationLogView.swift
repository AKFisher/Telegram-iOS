import Foundation

final class MutablePeerMergedOperationLogView {
    let tag: PeerOperationLogTag
    var entries: [PeerMergedOperationLogEntry]
    var tailIndex: Int32?
    let limit: Int
    
    init(tag: PeerOperationLogTag, limit: Int, getOperations: (PeerOperationLogTag, Int32, Int) -> [PeerMergedOperationLogEntry], getTailIndex: (PeerOperationLogTag) -> Int32?) {
        self.tag = tag
        self.entries = getOperations(tag, 0, limit)
        self.tailIndex = getTailIndex(tag)
        self.limit = limit
    }
    
    func replay(operations: [PeerMergedOperationLogOperation], getOperations: (PeerOperationLogTag, Int32, Int) -> [PeerMergedOperationLogEntry], getTailIndex: (PeerOperationLogTag) -> Int32?) -> Bool {
        var updated = false
        var invalidatedTail = false
        
        for operation in operations {
            switch operation {
                case let .append(entry):
                    if entry.tag == self.tag {
                        if let tailIndex = self.tailIndex {
                            assert(entry.mergedIndex > tailIndex)
                            self.tailIndex = entry.mergedIndex
                            if self.entries.count < self.limit {
                                self.entries.append(entry)
                                updated = true
                            }
                        } else {
                            updated = true
                            assert(self.entries.isEmpty)
                            self.entries.append(entry)
                            self.tailIndex = entry.mergedIndex
                        }
                    }
                case let .remove(tag, mergedIndices):
                    if tag == self.tag {
                        updated = true
                        for i in (0 ..< self.entries.count).reversed() {
                            if mergedIndices.contains(self.entries[i].mergedIndex) {
                                self.entries.remove(at: i)
                            }
                        }
                        if let tailIndex = self.tailIndex, mergedIndices.contains(tailIndex) {
                            self.tailIndex = nil
                            invalidatedTail = true
                        }
                    }
            }
        }
    
        if updated {
            if invalidatedTail {
                self.tailIndex = getTailIndex(self.tag)
            }
            if self.entries.count < self.limit {
                if let tailIndex = self.tailIndex {
                    if self.entries.isEmpty || self.entries.last!.mergedIndex < tailIndex {
                        var fromIndex: Int32 = 0
                        if !self.entries.isEmpty {
                            fromIndex = self.entries.last!.mergedIndex + 1
                        }
                        for entry in getOperations(self.tag, fromIndex, self.limit - self.entries.count) {
                            self.entries.append(entry)
                        }
                        for i in 0 ..< self.entries.count {
                            if i != 0 {
                                assert(self.entries[i].mergedIndex == self.entries[i - 1].mergedIndex + 1)
                            }
                        }
                        if !self.entries.isEmpty {
                            assert(self.entries.last!.mergedIndex <= tailIndex)
                        }
                    }
                }
            } else {
                assert(self.tailIndex != nil)
                if let tailIndex = self.tailIndex {
                    assert(self.entries.last!.mergedIndex == tailIndex)
                }
            }
        }
        
        return updated
    }
}

public final class PeerMergedOperationLogView {
    public let entries: [PeerMergedOperationLogEntry]
    
    init(_ view: MutablePeerMergedOperationLogView) {
       self.entries = view.entries
    }
}
