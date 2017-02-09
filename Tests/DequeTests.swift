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

import XCTest
@testable import Deque

private func cast<Source, Target>(_ value: Source) -> Target { return value as! Target }

func XCTAssertElementsEqual<Element: Equatable, S: Sequence>(_ a: S, _ b: [Element], file: StaticString = #file, line: UInt = #line)  where S.Iterator.Element == Element {
    let aa = Array(a)
    if !aa.elementsEqual(b) {
        XCTFail("XCTAssertEqual failed: \"\(aa)\" is not equal to \"\(b)\"", file: cast(file), line: line)
    }
}

// A reference type that consists of an integer value. This makes it easier to check problems with initialization.
private final class T: Comparable, CustomStringConvertible, CustomDebugStringConvertible, ExpressibleByIntegerLiteral {
    let value: Int
    
    init(_ value: Int) {
        self.value = value
    }
    required init(integerLiteral value: IntegerLiteralType) {
        self.value = numericCast(value)
    }
    
    var description: String { return String(value) }
    var debugDescription: String { return String(value) }
}

private func ==(a: T, b: T) -> Bool {
    return a.value == b.value
}
private func <(a: T, b: T) -> Bool {
    return a.value < b.value
}


class DequeTests: XCTestCase {
    
    func testEmptyDeque() {
        let deque = Deque<T>()
        XCTAssertEqual(deque.count, 0)
        XCTAssertTrue(deque.isEmpty)
        XCTAssertElementsEqual(deque, [])
    }
    
    func testDequeWithSingleItem() {
        let deque = Deque<T>([42])
        XCTAssertEqual(deque.count, 1)
        XCTAssertFalse(deque.isEmpty)
        XCTAssertEqual(deque[0], 42)
        XCTAssertElementsEqual(deque, [42])
    }
    
    func testDequeWithSomeItems() {
        let deque = Deque<T>([23, 42, 77, 111])
        XCTAssertEqual(deque.count, 4)
        XCTAssertEqual(deque[0], 23)
        XCTAssertEqual(deque[1], 42)
        XCTAssertEqual(deque[2], 77)
        XCTAssertEqual(deque[3], 111)
        XCTAssertElementsEqual(deque, [23, 42, 77, 111])
    }
    
    func testArrayLiteral() {
        let deque: Deque<T> = [1, 7, 3, 2, 6, 5, 4]
        XCTAssertElementsEqual(deque, [1, 7, 3, 2, 6, 5, 4])
    }
    
    func testAppend() {
        var deque: Deque<T> = [1, 2, 3]
        let deque2 = deque
        
        deque.append(4)
        XCTAssertElementsEqual(deque, [1, 2, 3, 4])
        
        deque.append(5)
        XCTAssertElementsEqual(deque, [1, 2, 3, 4, 5])
        
        deque.append(6)
        XCTAssertElementsEqual(deque, [1, 2, 3, 4, 5, 6])
        
        XCTAssertElementsEqual(deque2, [1, 2, 3])
    }
    
    func testRemoveAtIndex() {
        var deque: Deque<T> = [1, 2, 3, 4]
        let deque2 = deque
        
        let _ = deque.remove(at: 2)
        XCTAssertElementsEqual(deque, [1, 2, 4])
        
        let _ = deque.remove(at: 0)
        XCTAssertElementsEqual(deque, [2, 4])
        
        let _ = deque.remove(at: 1)
        XCTAssertElementsEqual(deque, [2])
        
        let _ = deque.remove(at: 0)
        XCTAssertElementsEqual(deque, [])
        
        XCTAssertElementsEqual(deque2, [1, 2, 3, 4])
    }
    
    func testRemoveFirst() {
        var deque: Deque<T> = [1, 2, 3, 4]
        let deque2 = deque
        
        XCTAssertEqual(deque.remove(at: 0), 1)
        XCTAssertElementsEqual(deque, [2, 3, 4])
        
        XCTAssertEqual(deque.remove(at: 0), 2)
        XCTAssertElementsEqual(deque, [3, 4])
        
        XCTAssertEqual(deque.remove(at: 0), 3)
        XCTAssertElementsEqual(deque, [4])
        
        XCTAssertEqual(deque.remove(at: 0), 4)
        XCTAssertElementsEqual(deque, [])
        
        XCTAssertElementsEqual(deque2, [1, 2, 3, 4])
    }
    
    
    func testRemoveLast() {
        var deque: Deque<T> = [1, 2, 3]
        let deque2 = deque
        
        XCTAssertEqual(deque.remove(at: deque.endIndex - 1), 3)
        XCTAssertElementsEqual(deque, [1, 2])
        
        XCTAssertEqual(deque.remove(at: deque.endIndex - 1), 2)
        XCTAssertElementsEqual(deque, [1])
        
        XCTAssertEqual(deque.remove(at: deque.endIndex - 1), 1)
        XCTAssertElementsEqual(deque, [])
        
        XCTAssertElementsEqual(deque2, [1, 2, 3])
    }
    
    func testRemove() {
        var deque = Deque<T>((0 ..< 1000).map { T($0) })
        let deque2 = deque
        
        deque.removeAll()
        XCTAssertElementsEqual(deque, [])
        
        XCTAssertElementsEqual(deque2, (0 ..< 1000).map { T($0) })
    }
    
    func testFrontInsert() {
        var deque: Deque<T> = [1, 2, 3]
        let deque2 = deque
        
        deque.insert(-1, at: 0)
        XCTAssertElementsEqual(deque, [-1, 1, 2, 3])
        
        deque.insert(-2, at: 0)
        XCTAssertElementsEqual(deque, [-2, -1, 1, 2, 3])
        
        deque.insert(-3, at: 0)
        XCTAssertElementsEqual(deque, [-3, -2, -1, 1, 2, 3])
        
        XCTAssertElementsEqual(deque2, [1, 2, 3])
    }
    
    func testForEachSimple() {
        let d1 = Deque<T>([0, 1, 2, 3, 4])
        var r1: [T] = []
        d1.forEach { i in r1.append(i) }
        XCTAssertEqual(r1, [0, 1, 2, 3, 4])
    }
    
    func testForEachMutating() {
        var d = Deque<T>([0, 1, 2, 3, 4])
        let orig = d
        var r: [T] = []
        d.forEach { i in
            r.append(i)
            d.append(T(d.count))
        }
        XCTAssertEqual(r, [0, 1, 2, 3, 4])
        XCTAssertElementsEqual(d, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        XCTAssertElementsEqual(orig, [0, 1, 2, 3, 4])
    }
}
