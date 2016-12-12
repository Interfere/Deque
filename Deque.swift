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

/// A double-ended queue.
///
/// You use a deque instead of an array when you need to efficiently insert
/// or remove elements from start or end of the collection.
public struct Deque<Element>: RandomAccessCollection, MutableCollection {
    
    private var _buffer: RingBuffer<Element>
    
    /// Creates a new, empty deque.
    ///
    /// Example:
    ///
    ///     var emptyDeque = Deque<Int>()
    ///     print(emptyArray.isEmpty)
    ///     // Prints "true"
    public init() {
        self._buffer = RingBuffer.create()
    }
    
    private init(minimumCapacity: Int) {
        self._buffer = RingBuffer.create(minimumCapacity: minimumCapacity)
    }
    
    /// Creates a deque containing the elements of a sequence.
    ///
    /// You can use this initializer to create a deque from any other type that
    /// conforms to the `Sequence` protocol. For example, you might want to
    /// create a deque with the integers from 1 through 7. Use this initializer
    /// around a range instead of typing all those numbers in an array literal.
    ///
    ///     let numbers = Deque(1...7)
    ///     print(numbers)
    ///     // Prints "[:| 1, 2, 3, 4, 5, 6, 7 |:]"
    ///
    ///
    /// - Parameter s: The sequence of elements to turn into deque.
    public init<S>(_ s: S) where S: Sequence, S.Iterator.Element == Element {
        self.init(minimumCapacity: s.underestimatedCount)
        self.append(contentsOf: s)
    }
    
    /// Creates a new deque containing the specified number of a single, repeated
    /// value.
    ///
    /// Here's an example of creating a deque initialized with five strings
    /// containing the letter *Z*.
    ///
    ///     let fiveZs = Deque(repeating: "Z", count: 5)
    ///     print(fiveZs)
    ///     // Prints "[:| "Z", "Z", "Z", "Z", "Z" |:]"
    ///
    /// - Parameters:
    ///   - repeatedValue: The element to repeat.
    ///   - count: The number of times to repeat the value passed in the
    ///     `repeating` parameter. `count` must be zero or greater.
    public init(repeating repeatedValue: Element, count: Int) {
        self._buffer = RingBuffer.create(minimumCapacity: count)
        for _ in 0..<count {
            self._buffer.append(repeatedValue)
        }
    }
    
    /// The number of elements in the deque.
    public var count: Int {
        return self._buffer.count
    }
    
    /// The total number of elements that the deque can contain using its current
    /// storage.
    ///
    /// If the deque grows larger than its capacity, it discards its current
    /// storage and allocates a larger one.
    ///
    /// The following example creates an deque of integers from an deque literal,
    /// then appends the elements of another collection. Before appending, the
    /// deque allocates new storage that is large enough store the resulting
    /// elements.
    ///
    ///     var numbers = Deque([10, 20, 30, 40, 50])
    ///     print("Count: \(numbers.count), capacity: \(numbers.capacity)")
    ///     // Prints "Count: 5, capacity: 5"
    ///
    ///     numbers.append(contentsOf: stride(from: 60, through: 100, by: 10))
    ///     print("Count: \(numbers.count), capacity: \(numbers.capacity)")
    ///     // Prints "Count: 10, capacity: 12"
    public var capacity: Int {
        return _buffer.capacity
    }
    
    private mutating func requestUniqueMutableBackingBuffer(minimumCapacity: Int) -> RingBuffer<Element>? {
        if _fastPath(isKnownUniquelyReferenced(&self._buffer) && capacity >= minimumCapacity) {
            return self._buffer
        }
        return nil
    }
    
    /// Reserves enough space to store the specified number of elements.
    ///
    /// If you are adding a known number of elements to an deque, use this method
    /// to avoid multiple reallocations. This method ensures that the deque has
    /// unique, mutable, contiguous storage, with space allocated for at least
    /// the requested number of elements.
    ///
    /// For performance reasons, the newly allocated storage may be larger than
    /// the requested capacity. Use the deque's `capacity` property to determine
    /// the size of the new storage.
    ///
    /// - Parameter minimumCapacity: The requested number of elements to store.
    ///
    /// - Complexity: O(*n*), where *n* is the count of the deque.
    public mutating func reserveCapacity(_ minimumCapacity: Int){
        if requestUniqueMutableBackingBuffer(minimumCapacity: minimumCapacity) == nil {
            let newBuffer = RingBuffer<Element>.create(minimumCapacity: minimumCapacity)
            newBuffer.copyContents(self._buffer)
            self._buffer = newBuffer
        }
        
        assert(capacity >= minimumCapacity)
    }
    
    /// Adds a new element at the end of the deque.
    ///
    /// Use this method to append a single element to the end of a mutable deque.
    ///
    ///     var numbers = Deque([1, 2, 3, 4, 5])
    ///     numbers.append(100)
    ///     print(numbers)
    ///     // Prints "[:| 1, 2, 3, 4, 5, 100 |:]"
    ///
    /// Because deques increase their allocated capacity using an exponential
    /// strategy, appending a single element to an deque is an O(1) operation
    /// when averaged over many calls to the `append(_:)` method. When deque
    /// has additional capacity and is not sharing its storage with another
    /// instance, appending an element is O(1). When deque needs to
    /// reallocate storage before appending or its storage is shared with
    /// another copy, appending is O(*n*), where *n* is the length of the deque.
    ///
    /// - Parameter newElement: The element to append to the deque.
    ///
    /// - Complexity: Amortized O(1) over many additions.
    public mutating func append(_ newElement: Element) {
        reserveCapacity(count + 1)
        _buffer.append(newElement)
    }
    
    
    /// Adds the elements of a sequence to the end of the deque.
    ///
    /// Use this method to append the elements of a sequence to the end of a
    /// deque. This example appends the elements of a `Range<Int>` instance
    /// to a deque of integers.
    ///
    ///     var numbers = Deque([1, 2, 3, 4, 5])
    ///     numbers.append(contentsOf: 10...15)
    ///     print(numbers)
    ///     // Prints "[:| 1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15 |:]"
    ///
    /// - Parameter newElements: The elements to append to the deque.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the resulting deque.
    public mutating func append<S : Sequence>(contentsOf newElements: S) where S.Iterator.Element == Element {
        reserveCapacity(count + newElements.underestimatedCount)
        var stream = _buffer.append(newElements.underestimatedCount, elementsOf: newElements)
        while let nextElement = stream.next() {
            append(nextElement)
        }
    }
    
    /// Adds the elements of a collection to the end of the deque.
    ///
    /// Use this method to append the elements of a collection to the end of this
    /// deque. This example appends the elements of a `Range<Int>` instance
    /// to an deque of integers.
    ///
    ///     var numbers = Deque([1, 2, 3, 4, 5])
    ///     numbers.append(contentsOf: 10...15)
    ///     print(numbers)
    ///     // Prints "[:| 1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15 |:]"
    ///
    /// - Parameter newElements: The elements to append to the deque.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the resulting deque.
    public mutating func append<C : Collection>(contentsOf newElements: C) where C.Iterator.Element == Element {
        replaceSubrange(endIndex..<endIndex, with: newElements)
    }
    
    /// Adds a new element at the start of the deque.
    ///
    /// Use this method to prepend a single element at the start of a mutable deque.
    ///
    ///     var numbers = Deque([1, 2, 3, 4, 5])
    ///     numbers.prepend(100)
    ///     print(numbers)
    ///     // Prints "[:| 100, 1, 2, 3, 4, 5 |:]"
    ///
    /// Because deques increase their allocated capacity using an exponential
    /// strategy, prepending a single element to deque is an O(1) operation
    /// when averaged over many calls to the `prepend(_:)` method. When deque
    /// has additional capacity and is not sharing its storage with another
    /// instance, prepending an element is O(1). When deque needs to
    /// reallocate storage before prepending or its storage is shared with
    /// another copy, prepending is O(*n*), where *n* is the length of the deque.
    ///
    /// - Parameter newElement: The element to prepend to the deque.
    ///
    /// - Complexity: Amortized O(1) over many additions.
    public mutating func prepend(_ newElement: Element) {
        reserveCapacity(count + 1)
        _buffer.prepend(newElement)
    }
    
    /// Inserts a new element at the specified position.
    ///
    /// The new element is inserted before the element currently at the specified
    /// index. If you pass the deque's `endIndex` property as the `index`
    /// parameter, the new element is appended to the deque; if you pass `startIndex`
    /// property, the new element is prepended to the deque.
    ///
    ///     var numbers = Deque([1, 2, 3, 4, 5])
    ///     numbers.insert(100, at: 3)
    ///     numbers.insert(200, at: numbers.endIndex)
    ///     numbers.insert(300, at: numbers.startIndex)
    ///
    ///     print(numbers)
    ///     // Prints "[:| 300, 1, 2, 3, 100, 4, 5, 200 |:]"
    ///
    /// - Parameter newElement: The new element to insert into the deque.
    /// - Parameter i: The position at which to insert the new element.
    ///   `index` must be a valid index of the deque or equal to its `endIndex`
    ///   property.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the deque.
    public mutating func insert(_ newElement: Element, at i: Int) {
        precondition(i >= startIndex && i <= endIndex, "Deque insert: index out of bounds")
        replaceSubrange(i..<i, with: CollectionOfOne(newElement))
    }
    
    /// Removes and returns the element at the specified position.
    ///
    /// All the elements following the specified position are moved up to
    /// close the gap.
    ///
    ///     var measurements: Deque<Double> = Deque([1.1, 1.5, 2.9, 1.2, 1.5, 1.3, 1.2])
    ///     let removed = measurements.remove(at: 2)
    ///     print(measurements)
    ///     // Prints "[:| 1.1, 1.5, 1.2, 1.5, 1.3, 1.2 |:]"
    ///
    /// - Parameter index: The position of the element to remove. `index` must
    ///   be a valid index of the deque.
    /// - Returns: The element at the specified index.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the deque.
    public mutating func remove(at index: Int) -> Element {
        precondition(index >= startIndex && index < endIndex, "Deque remove: index out of bounds")
        let result = self[index]
        replaceSubrange(index..<(index + 1), with: EmptyCollection())
        return result
    }
    
    /// Removes all elements from the deque.
    ///
    /// - Parameter keepCapacity: Pass `true` to keep the existing capacity of
    ///   the deque after removing its elements. The default value is
    ///   `false`.
    ///
    /// - Complexity: O(*n*), where *n* is the length of the deque.
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        if !keepCapacity {
            _buffer = RingBuffer.create()
        }
        else {
            replaceSubrange(Range(self.indices), with: EmptyCollection())
        }
    }
    
    /// Replaces a range of elements with the elements in the specified
    /// collection.
    ///
    /// This method has the effect of removing the specified range of elements
    /// from the deque and inserting the new elements at the same location. The
    /// number of new elements need not match the number of elements being
    /// removed.
    ///
    /// In this example, three elements in the middle of deque of integers are
    /// replaced by the five elements of a `Repeated<Int>` instance.
    ///
    ///      var nums = Deque([10, 20, 30, 40, 50])
    ///      nums.replaceSubrange(1...3, with: repeatElement(1, count: 5))
    ///      print(nums)
    ///      // Prints "[:| 10, 1, 1, 1, 1, 1, 50 |:]"
    ///
    /// If you pass a zero-length range as the `subrange` parameter, this method
    /// inserts the elements of `newElements` at `subrange.startIndex`. Calling
    /// the `insert(contentsOf:at:)` method instead is preferred.
    ///
    /// Likewise, if you pass a zero-length collection as the `newElements`
    /// parameter, this method removes the elements in the given subrange
    /// without replacement. Calling the `removeSubrange(_:)` method instead is
    /// preferred.
    ///
    /// - Parameters:
    ///   - subrange: The subrange of the deque to replace. The start and end of
    ///     a subrange must be valid indices of the deque.
    ///   - newElements: The new elements to add to the deque.
    ///
    /// - Complexity: O(`subrange.count`) if you are replacing a suffix or a prefix
    ///   of the deque with an empty collection; otherwise, O(*n*), where *n* is the
    ///   length of the deque.
    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C)  where C : Collection, C.Iterator.Element == Element {
        precondition(subrange.lowerBound >= _buffer.startIndex, "Deque replace: subrange start is negative")
        precondition(subrange.upperBound <= _buffer.endIndex, "Deque replace: subrange extends past the end")
        
        let oldCount = _buffer.count
        let eraseCount = subrange.count
        let insertCount = numericCast(newElements.count) as Int
        let growth = insertCount - eraseCount
        
        if requestUniqueMutableBackingBuffer(minimumCapacity: oldCount + growth) != nil {
            _buffer.replaceSubrange(subrange, with: insertCount, elementsOf: newElements)
        } else {
            _buffer = _buffer.copyReplacingSubrange(subrange, with: insertCount, elementsOf: newElements)
        }
    }
    
    /// A type that represents a position in the collection.
    ///
    /// Valid indices consist of the position of every element and a
    /// "past the end" position that's not valid for use as a subscript
    /// argument.
    ///
    /// - SeeAlso: endIndex
    public typealias Index = Int
    
    /// The position of the first element in a nonempty deque.
    ///
    /// For an instance of `Deque`, `startIndex` is always zero. If the deque
    /// is empty, `startIndex` is equal to `endIndex`.
    public var startIndex: Int {
        return 0
    }
    
    /// The deque's "past the end" position---that is, the position one greater
    /// than the last valid subscript argument.
    ///
    /// When you need a range that includes the last element of an deque, use the
    /// half-open range operator (`..<`) with `endIndex`. The `..<` operator
    /// creates a range that doesn't include the upper bound, so it's always
    /// safe to use with `endIndex`. For example:
    ///
    ///     let numbers = Deque([10, 20, 30, 40, 50])
    ///     if let i = numbers.index(of: 30) {
    ///         print(numbers[i ..< numbers.endIndex])
    ///     }
    ///     // Prints "[30, 40, 50]"
    ///
    /// If the deque is empty, `endIndex` is equal to `startIndex`.
    public var endIndex: Int {
        return _buffer.count
    }
    
    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Int) -> Int {
        return i + 1
    }
    
    /// Replaces the given index with its successor.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    public func formIndex(after i: inout Int) {
        i += 1
    }
    
    /// Returns the position immediately before the given index.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be greater than
    ///   `startIndex`.
    /// - Returns: The index value immediately before `i`.
    public func index(before i: Int) -> Int {
        return i - 1
    }
    
    /// Replaces the given index with its predecessor.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be greater than
    ///   `startIndex`.
    public func formIndex(before i: inout Int) {
        i -= 1
    }
    
    /// Returns an index that is the specified distance from the given index.
    ///
    /// The following example obtains an index advanced four positions from an
    /// deque starting index and then prints the element at that position.
    ///
    ///     let numbers = [10, 20, 30, 40, 50]
    ///     let i = numbers.index(numbers.startIndex, offsetBy: 4)
    ///     print(numbers[i])
    ///     // Prints "50"
    ///
    /// Advancing an index beyond a collection's ending index or offsetting it
    /// before a collection's starting index may trigger a runtime error. The
    /// value passed as `n` must not result in such an operation.
    ///
    /// - Parameters:
    ///   - i: A valid index of the deque.
    ///   - n: The distance to offset `i`.
    /// - Returns: An index offset by `n` from the index `i`. If `n` is positive,
    ///   this is the same value as the result of `n` calls to `index(after:)`.
    ///   If `n` is negative, this is the same value as the result of `-n` calls
    ///   to `index(before:)`.
    ///
    /// - Complexity: O(1)
    public func index(_ i: Int, offsetBy n: Int) -> Int {
        return i + n
    }
    
    /// Returns an index that is the specified distance from the given index,
    /// unless that distance is beyond a given limiting index.
    ///
    /// The following example obtains an index advanced four positions from an
    /// deque's starting index and then prints the element at that position. The
    /// operation doesn't require going beyond the limiting `numbers.endIndex`
    /// value, so it succeeds.
    ///
    ///     let numbers = [10, 20, 30, 40, 50]
    ///     let i = numbers.index(numbers.startIndex,
    ///                           offsetBy: 4,
    ///                           limitedBy: numbers.endIndex)
    ///     print(numbers[i])
    ///     // Prints "50"
    ///
    /// The next example attempts to retrieve an index ten positions from
    /// `numbers.startIndex`, but fails, because that distance is beyond the
    /// index passed as `limit`.
    ///
    ///     let j = numbers.index(numbers.startIndex,
    ///                           offsetBy: 10,
    ///                           limitedBy: numbers.endIndex)
    ///     print(j)
    ///     // Prints "nil"
    ///
    /// Advancing an index beyond a collection's ending index or offsetting it
    /// before a collection's starting index may trigger a runtime error. The
    /// value passed as `n` must not result in such an operation.
    ///
    /// - Parameters:
    ///   - i: A valid index of the deque.
    ///   - n: The distance to offset `i`.
    ///   - limit: A valid index of the collection to use as a limit. If `n > 0`,
    ///     `limit` has no effect if it is less than `i`. Likewise, if `n < 0`,
    ///     `limit` has no effect if it is greater than `i`.
    /// - Returns: An index offset by `n` from the index `i`, unless that index
    ///   would be beyond `limit` in the direction of movement. In that case,
    ///   the method returns `nil`.
    ///
    /// - SeeAlso: `index(_:offsetBy:)`, `formIndex(_:offsetBy:limitedBy:)`
    /// - Complexity: O(1)
    public func index(_ i: Int, offsetBy n: Int, limitedBy limit: Int) -> Int? {
        let j = i + n
        return j > limit ? nil : j
    }
    
    /// Returns the distance between two indices.
    ///
    /// - Parameters:
    ///   - start: A valid index of the collection.
    ///   - end: Another valid index of the collection. If `end` is equal to
    ///     `start`, the result is zero.
    /// - Returns: The distance between `start` and `end`.
    public func distance(from start: Int, to end: Int) -> Int {
        return end - start
    }
    
    /// A type that can represent the indices that are valid for subscripting the
    /// collection, in ascending order.
    public typealias Indices = CountableRange<Int>
    
    /// The indices that are valid for subscripting the collection, in ascending
    /// order.
    ///
    /// A collection's `indices` property can hold a strong reference to the
    /// collection itself, causing the collection to be non-uniquely referenced.
    /// If you mutate the collection while iterating over its indices, a strong
    /// reference can cause an unexpected copy of the collection. To avoid the
    /// unexpected copy, use the `index(after:)` method starting with
    /// `startIndex` to produce indices instead.
    ///
    ///     var c = MyFancyCollection([10, 20, 30, 40, 50])
    ///     var i = c.startIndex
    ///     while i != c.endIndex {
    ///         c[i] /= 5
    ///         i = c.index(after: i)
    ///     }
    ///     // c == MyFancyCollection([2, 4, 6, 8, 10])
    public var indices: CountableRange<Int> {
        return startIndex..<endIndex
    }
    
    /// Accesses the element at the specified position.
    ///
    /// The following example uses indexed subscripting to update an deque's
    /// second element. After assigning the new value (`"Butler"`) at a specific
    /// position, that value is immediately available at that same position.
    ///
    ///     var streets = Deque(["Adams", "Bryant", "Channing", "Douglas", "Evarts"])
    ///     streets[1] = "Butler"
    ///     print(streets[1])
    ///     // Prints "Butler"
    ///
    /// - Parameter index: The position of the element to access. `index` must be
    ///   greater than or equal to `startIndex` and less than `endIndex`.
    ///
    /// - Complexity: Reading an element from an deque is O(1). Writing is O(1)
    ///   unless the deque's storage is shared with another deque, in which case
    ///   writing is O(*n*), where *n* is the length of the deque.
    public subscript(index: Int) -> Element {
        get {
            precondition(index >= _buffer.startIndex && index < _buffer.endIndex, "Deque subscript: index {\(index)} out of bounds (\(_buffer.startIndex)..<\(_buffer.endIndex))")
            return _buffer.at(index: index)
        }
        set {
            precondition(index >= _buffer.startIndex && index < _buffer.endIndex, "Deque subscript: index out of bounds")
            replaceSubrange(index..<(index + 1), with: CollectionOfOne(newValue))
        }
    }
    
    /// Accesses a contiguous subrange of the deque's elements.
    ///
    /// The returned `RandomAccessSlice` instance uses the same indices for the
    /// same elements as the original deque. In particular, that slice, unlike an
    /// deque, may have a nonzero `startIndex` and an `endIndex` that is not
    /// equal to `count`. Always use the slice's `startIndex` and `endIndex`
    /// properties instead of assuming that its indices start or end at a
    /// particular value.
    ///
    /// This example demonstrates getting a slice of a deque of strings, finding
    /// the index of one of the strings in the slice, and then using that index
    /// in the original deque.
    ///
    ///     let streets: Deque<String> = ["Adams", "Bryant", "Channing", "Douglas", "Evarts"]
    ///     let streetsSlice = streets[2 ..< streets.endIndex]
    ///     print(streetsSlice)
    ///     // Prints "["Channing", "Douglas", "Evarts"]"
    ///
    ///     let i = streetsSlice.index(of: "Evarts")    // 4
    ///     print(streets[i!])
    ///     // Prints "Evarts"
    ///
    /// - Parameter bounds: A range of integers. The bounds of the range must be
    ///   valid indices of the deque.
    ///
    /// - SeeAlso: `RandomAccessSlice`
    public subscript(bounds: Range<Int>) -> RandomAccessSlice<Deque> {
        get {
            precondition(bounds.lowerBound >= _buffer.startIndex, "Deque subscript: subrange start is negative")
            precondition(bounds.upperBound <= _buffer.endIndex, "Deque subscript: subrange extends past the end")
            return RandomAccessSlice(base: self, bounds: bounds)
        }
        set {
            precondition(bounds.lowerBound >= _buffer.startIndex, "Deque subscript: subrange start is negative")
            precondition(bounds.upperBound <= _buffer.endIndex, "Deque subscript: subrange extends past the end")
            if self._buffer.identity != newValue.base._buffer.identity {
                replaceSubrange(bounds, with: newValue)
            }
        }
    }
}
