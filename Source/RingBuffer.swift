// MIT License
//
// Copyright (c) 2016 Alexey Komnin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

fileprivate struct _RingBufferHeader {
    fileprivate let capacity: Int
    fileprivate var count: Int = 0
    fileprivate var offset: Int = 0
    
    fileprivate init(capacity: Int) {
        self.capacity = capacity
    }
    
    fileprivate var isSplitted: Bool {
        return offset + count > capacity
    }
    
    fileprivate var startIndex: Int {
        return offset
    }
    
    fileprivate var endIndex: Int {
        return (offset + count) % capacity
    }
    
    fileprivate func index(after i: Int) -> Int {
        let i = (i + 1)
        return i == capacity ? 0 : i
    }
    
    fileprivate func formIndex(after i: inout Int) {
        i = index(after: i)
    }
    
    fileprivate func index(before i: Int) -> Int {
        return i == 0 ? capacity - 1 : i - 1
    }
    
    fileprivate func index(_ i: Int, offsetBy n: Int) -> Int {
        return (i + n + capacity) % capacity
    }
    
    fileprivate func distance(from start: Int, to end: Int) -> Int {
        return end >= start ? end - start : end + (capacity - start)
    }
    
    fileprivate func splitRange(_ range: Range<Int>) -> (Range<Int>, Range<Int>) {
        assert(!range.isEmpty)
        assert(range.lowerBound >= 0 && distance(from: index(startIndex, offsetBy: range.upperBound), to: endIndex) >= 0)
        
        let lowerIdx = startIndex + range.lowerBound
        let upperIdx = startIndex + range.upperBound
        
        /// 1. If buffer is not splitted then just move tail
        guard isSplitted else {
            if upperIdx % capacity == 0 {
                return (0..<0, (lowerIdx % capacity)..<capacity)
            } else {
                return ((lowerIdx % capacity)..<(upperIdx % capacity), 0..<0)
            }
        }
        
        /// 2. If buffer is splitted and the range is not
        guard lowerIdx < capacity && upperIdx >= capacity else {
            /// 2.1. check if we in the bottom chunk or in the top
            return upperIdx < capacity ? (lowerIdx..<upperIdx, 0..<0) : (0..<0, (lowerIdx - capacity)..<(upperIdx - capacity))
        }
        
        /// 3. The buffer is splitted and the range too
        return (lowerIdx..<capacity, 0..<(upperIdx - capacity))
    }
}

final class RingBuffer<Element> {
    private typealias _Buffer = ManagedBufferPointer<_RingBufferHeader, Element>
    
    @available(*, unavailable)
    private init() {
        fatalError("init(): not initialized")
    }
    
    static func create(minimumCapacity: Int = 32) -> RingBuffer<Element> {
        let p = _Buffer(bufferClass: self, minimumCapacity: minimumCapacity) { buffer, allocatedCount in
            return _RingBufferHeader(capacity: allocatedCount(buffer))
        }
        return unsafeDowncast(p.buffer, to: self)
    }
    
    private var _header: _RingBufferHeader {
        return _Buffer(unsafeBufferObject: self).header
    }
    
    public var capacity: Int {
        return self._header.capacity
    }
    
    var count: Int {
        return self._header.count
    }
    
    var startIndex: Int {
        return 0
    }
    
    var endIndex: Int {
        return count
    }
    
    /// A value that identifies the storage used by the buffer.
    ///
    /// Two buffers address the same elements when they have the same
    /// identity and count.
    var identity: UnsafeRawPointer {
        return _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers{ hptr, eptr in
            UnsafeRawPointer(eptr.advanced(by: hptr.pointee.startIndex))
        }
    }
    
    deinit {
        /// quick check and exit if no data for deinitialization
        guard count > 0 else { return }
        
        _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers { hptr, eptr in
            if hptr.pointee.isSplitted {
                /// 1. buffer is splitted:    [***---------***]
                let chunkSize = hptr.pointee.capacity - hptr.pointee.offset
                eptr.deinitialize(count: hptr.pointee.count - chunkSize)
                eptr.advanced(by: hptr.pointee.offset).deinitialize(count: chunkSize)
            } else {
                /// 2. buffer is contiguous:  [---*********---]
                eptr.advanced(by: hptr.pointee.offset).deinitialize(count: hptr.pointee.count)
            }
            hptr.deinitialize()
        }
    }
    
    func at(index: Int) -> Element {
        assert((0..<count).contains(index))
        
        return _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers { hptr, eptr in
            return eptr[hptr.pointee.index(hptr.pointee.startIndex, offsetBy: index)]
        }
    }

    func append(_ element: Element) {
        assert(count + 1 <= capacity)
        
        _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers { hptr, eptr in
            hptr.pointee.count += 1
            eptr.advanced(by: hptr.pointee.index(hptr.pointee.startIndex, offsetBy: hptr.pointee.count - 1)).initialize(to: element)
        }
    }
    
    func prepend(_ element: Element) {
        assert(count + 1 <= capacity)
        
        _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers { hptr, eptr in
            hptr.pointee.count += 1
            hptr.pointee.offset = hptr.pointee.index(before: hptr.pointee.offset)
            eptr.advanced(by: hptr.pointee.startIndex).initialize(to: element)
        }
    }
    
    func replaceSubrange<C>(_ subrange: Range<Int>, with newCount: Int, elementsOf newValues: C)
        where C: Collection, C.Iterator.Element == Element {
            assert(subrange.lowerBound >= 0 && subrange.upperBound <= count)
            assert(newCount - subrange.count < capacity)
            
            if newCount > subrange.count {
                if subrange.upperBound == count {
                    _replaceAndAppend(subrange, with: newCount, elementsOf: newValues)
                }
                else if subrange.lowerBound == 0 {
                    _replaceAndPrepend(subrange, with: newCount, elementsOf: newValues)
                }
                else {
                    _replaceAndGrow(subrange, with: newCount, elementsOf: newValues)
                }
            }
            else {
                _replaceAndShrink(subrange, with: newCount, elementsOf: newValues)
            }
    }
    
    func copyReplacingSubrange<C>(_ subrange: Range<Int>, with newCount: Int, elementsOf newValues: C) -> RingBuffer<Element>
        where C: Collection, C.Iterator.Element == Element
    {
        let eraseCount = subrange.count
        let growth = newCount - eraseCount
        let newBuffer = type(of: self).create(minimumCapacity: count + growth)
        
        _Buffer(unsafeBufferObject: newBuffer).withUnsafeMutablePointers { hptr, eptr in
            hptr.pointee.count = count + growth
            var i = hptr.pointee.startIndex
            for _ in 0..<subrange.lowerBound {
                eptr.advanced(by: i).initialize(to: at(index: i))
                hptr.pointee.formIndex(after: &i)
            }
            var j = newValues.startIndex
            for _ in 0..<newCount {
                eptr.advanced(by: i).initialize(to: newValues[j])
                hptr.pointee.formIndex(after: &i)
                newValues.formIndex(after: &j)
            }
            for k in subrange.upperBound..<count {
                eptr.advanced(by: i).initialize(to: at(index: k))
                hptr.pointee.formIndex(after: &i)
            }
        }
        
        return newBuffer
    }
    
    func copyContents(_ other: RingBuffer<Element>) {
        assert(capacity >= other.capacity)
        assert(count == 0 && other.count > 0)
        
        _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers { hptr, eptr in
            hptr.pointee.count = other.count
            for i in 0..<other.count {
                eptr.advanced(by: i).initialize(to: other.at(index: i))
            }
        }
    }
    
    func append<S: Sequence>(_ newCount: Int, elementsOf newValues: S) -> S.Iterator where S.Iterator.Element == Element {
        assert(count + newCount <= capacity)
        
        return _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers { hptr, eptr in
            var i = hptr.pointee.endIndex
            var actualCount = 0
            var stream = newValues.makeIterator()
            for _ in 0..<newCount {
                guard let value = stream.next() else {
                    break
                }
                eptr.advanced(by: i).initialize(to: value)
                hptr.pointee.formIndex(after: &i)
                actualCount += 1
            }
            hptr.pointee.count += actualCount
            
            return stream
        }
    }
    
    @inline(__always)
    final private func _replace<C>(_ ptr: UnsafeMutablePointer<Element>, startingAt index1: Int, with newCount: Int, elementsOf newValues: C, startingAt index2: C.Index) -> (Int, C.Index) where C: Collection, C.Iterator.Element == Element {
        var i = index1
        var j = index2
        for _ in 0..<newCount {
            ptr[i] = newValues[j]
            _header.formIndex(after: &i)
            newValues.formIndex(after: &j)
        }
        return (i, j)
    }
    
    @inline(__always)
    final private func _initialize<C>(_ ptr: UnsafeMutablePointer<Element>, startingAt index1: Int, with newCount: Int, elementsOf newValues: C, startingAt index2: C.Index) -> (Int, C.Index) where C: Collection, C.Iterator.Element == Element {
        var i = index1
        var j = index2
        for _ in 0..<newCount {
            ptr.advanced(by: i).initialize(to: newValues[j])
            _header.formIndex(after: &i)
            newValues.formIndex(after: &j)
        }
        return (i, j)
    }
    
    @inline(__always)
    final private func _replaceAndGrow<C>(_ subrange: Range<Int>, with newCount: Int, elementsOf newValues: C) where C: Collection, C.Iterator.Element == Element {
        assert(subrange.count < newCount)
        
        let eraseCount = subrange.count
        let growth = newCount - eraseCount
        
        _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers { hptr, eptr in
            if hptr.pointee.isSplitted {
                let (left, right) = hptr.pointee.splitRange(subrange)
                if right.isEmpty {
                    let oldHeadPtr = eptr.advanced(by: hptr.pointee.startIndex)
                    let newHeadPtr = oldHeadPtr.advanced(by: -growth)
                    
                    /// move the head...
                    newHeadPtr.moveInitialize(from: oldHeadPtr, count: subrange.lowerBound)
                    /// ...and fill the hole
                    let (i, j) = _initialize(eptr, startingAt: left.lowerBound, with: growth, elementsOf: newValues, startingAt: newValues.startIndex)
                    _ = _replace(eptr, startingAt: i, with: eraseCount, elementsOf: newValues, startingAt: j)
                    
                    /// ...adjust offset
                    hptr.pointee.offset -= growth
                }
                else {
                    let oldTailPtr = eptr.advanced(by: right.upperBound)
                    let newTailPtr = oldTailPtr.advanced(by: growth)
                    let tailCount = hptr.pointee.endIndex - right.upperBound
                    
                    /// move tail...
                    newTailPtr.moveInitialize(from: oldTailPtr, count: tailCount)
                    /// ...and fill the hole
                    let (i, j) = _replace(eptr, startingAt: 0, with: eraseCount, elementsOf: newValues, startingAt: newValues.startIndex)
                    _ = _initialize(eptr, startingAt: i, with: growth, elementsOf: newValues, startingAt: j)
                }
            }
            else {
                var growth = growth
                let headHoleSize = hptr.pointee.offset
                let tailHoleSize = hptr.pointee.capacity - hptr.pointee.endIndex
                
                let leftMoveDistance = min(growth, headHoleSize)
                growth -= leftMoveDistance
                let rightMoveDistance = min(growth, tailHoleSize)
                growth -= rightMoveDistance
                
                assert(growth == 0, "growth must equal to 0 now")
                
                /// prepare ptrs
                let oldHeadPtr = eptr.advanced(by: hptr.pointee.startIndex)
                let newHeadPtr = oldHeadPtr.advanced(by: -leftMoveDistance)
                let oldTailPtr = eptr.advanced(by: hptr.pointee.startIndex + subrange.upperBound)
                let newTailPtr = oldTailPtr.advanced(by: rightMoveDistance)
                let tailCount = hptr.pointee.endIndex - subrange.upperBound
                
                /// move the head...
                newHeadPtr.moveInitialize(from: oldHeadPtr, count: subrange.lowerBound)
                /// ... and tail
                newTailPtr.moveInitialize(from: oldTailPtr, count: tailCount)
                
                /// ... insert new elements
                var (i, j) = _initialize(eptr, startingAt: hptr.pointee.startIndex + subrange.lowerBound,
                                         with: leftMoveDistance, elementsOf: newValues, startingAt: newValues.startIndex)
                (i, j) = _replace(eptr, startingAt: i, with: eraseCount, elementsOf: newValues, startingAt: j)
                _ = _initialize(eptr, startingAt: i, with: rightMoveDistance, elementsOf: newValues, startingAt: j)
                
                /// ... adjust offset
                hptr.pointee.offset -= leftMoveDistance
            }
            
            /// ... finally, adjust count
            hptr.pointee.count += growth
        }
    }
    
    @inline(__always)
    final private func _replaceAndShrink<C>(_ subrange: Range<Int>, with newCount: Int, elementsOf newValues: C) where C: Collection, C.Iterator.Element == Element {
        assert(newCount <= subrange.count)
        
        let shrinkage = subrange.count - newCount
        
        _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers { hptr, eptr in
            /// 1. replace (part of) subrange with new values
            let i = hptr.pointee.index(hptr.pointee.startIndex, offsetBy: subrange.lowerBound)
            let j = _replace(eptr, startingAt: i, with: newCount, elementsOf: newValues, startingAt: newValues.startIndex).1
            
            assert(j == newValues.endIndex, "expected end of collection")
            
            /// if there are no elements to delete then we are done
            if shrinkage == 0 {
                return
            }
            
            /// 2. Otherwise remove elements
            let (left, right) = hptr.pointee.splitRange((subrange.lowerBound + newCount)..<subrange.upperBound)
            
            /// 2.1. Move head
            if !left.isEmpty {
                let headCount = hptr.pointee.distance(from: hptr.pointee.startIndex, to: left.lowerBound)
                let newHeadStart = eptr.advanced(by: left.upperBound - headCount)
                let oldHeadStart = eptr.advanced(by: hptr.pointee.startIndex)
                
                if headCount < left.count {
                    /// head is shorter than the hole. move as much as possible...
                    newHeadStart.moveAssign(from: oldHeadStart, count: headCount)
                    /// ... and destroy the rest
                    oldHeadStart.deinitialize(count: left.count - headCount)
                }
                else {
                    /// the hole is equal size or shorter than head. move elements to fill the hole...
                    newHeadStart.advanced(by: headCount - left.count).moveAssign(from: oldHeadStart.advanced(by: headCount - left.count), count: left.count)
                    /// ... then move the rest.
                    newHeadStart.moveInitialize(from: oldHeadStart, count: headCount - left.count)
                }
                
                /// adjust offset and count
                hptr.pointee.offset = hptr.pointee.index(hptr.pointee.offset, offsetBy: left.count)
                hptr.pointee.count -= left.count
                
            }
            
            /// 2.2. Move tail
            if !right.isEmpty {
                let tailCount = hptr.pointee.distance(from: right.upperBound, to: hptr.pointee.endIndex)
                let newTailStart = eptr.advanced(by: right.lowerBound)
                let oldTailStart = eptr.advanced(by: right.upperBound)
                
                if tailCount < right.count {
                    /// tail is shorter than the hole. move as much as possible...
                    newTailStart.moveAssign(from: oldTailStart, count: tailCount)
                    /// ... and destroy the rest
                    newTailStart.advanced(by: tailCount).deinitialize(count: right.count - tailCount)
                }
                else {
                    /// the hole is the same size or shorter than tail. move elements to fill the hole...
                    newTailStart.moveAssign(from: oldTailStart, count: right.count)
                    /// ... then move the rest of the tail.
                    newTailStart.advanced(by: right.count).moveInitialize(from: oldTailStart.advanced(by: right.count), count: tailCount - right.count)
                }
                
                /// adjust count
                hptr.pointee.count -= right.count
            }
        }
    }
    
    @inline(__always)
    final private func _replaceAndAppend<C>(_ subrange: Range<Int>, with newCount: Int, elementsOf newValues: C) where C: Collection, C.Iterator.Element == Element {
        assert(subrange.upperBound == count)
        
        _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers { hptr, eptr in
            let growth = newCount - subrange.count
            
            let tailOffset = hptr.pointee.index(hptr.pointee.endIndex, offsetBy: -subrange.count)
            let (i, j) = _replace(eptr, startingAt: tailOffset, with: subrange.count, elementsOf: newValues, startingAt: newValues.startIndex)
            _ = _initialize(eptr, startingAt: i, with: growth, elementsOf: newValues, startingAt: j)
            
            hptr.pointee.count += growth
        }
    }
    
    @inline(__always)
    final private func _replaceAndPrepend<C>(_ subrange: Range<Int>, with newCount: Int, elementsOf newValues: C) where C: Collection, C.Iterator.Element == Element {
        assert(subrange.lowerBound == 0)
        
        _Buffer(unsafeBufferObject: self).withUnsafeMutablePointers { hptr, eptr in
            let growth = newCount - subrange.count
            
            let newOffset = hptr.pointee.index(hptr.pointee.startIndex, offsetBy: -growth)
            let (i, j) = _initialize(eptr, startingAt: newOffset, with: growth, elementsOf: newValues, startingAt: newValues.startIndex)
            _ = _replace(eptr, startingAt: i, with: subrange.count, elementsOf: newValues, startingAt: j)
            
            /// adjust offset
            hptr.pointee.offset = newOffset
            hptr.pointee.count += growth
        }
    }
}

