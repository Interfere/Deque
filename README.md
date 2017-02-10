# Deque
Swift Double-ended queue implementation

[![Build Status](https://travis-ci.org/Interfere/Deque.svg?branch=master)](https://travis-ci.org/Interfere/Deque)
[![codecov](https://codecov.io/gh/Interfere/Deque/branch/master/graph/badge.svg)](https://codecov.io/gh/Interfere/Deque)
![Swift](https://img.shields.io/badge/%20in-swift%203.0-orange.svg)

## Description
**Double-ended queue** is a special kind of container which provides appending and prepending methods of amortized O(1) complexity. It is built on top of RingBuffer and provides Array-like interface.

## Example
Creating a deque:

```swift
let emptyDeque = Deque<String>()

let dequeFromArray: Deque<Int> = [1, 2, 3, 4]
```

Appending values:
```swift
var deque = Deque<String>()
deque.append("first element")

print(deque[0])
// Prints "first element"
```

Deque conforms to protocol `RangeReplaceableCollection` as well:
```swift
var nums: Deque<Int> = [10, 20, 30, 40, 50]
nums.replaceSubrange(1...3, with: repeatElement(1, count: 5))
print(nums)
// Prints "[10, 1, 1, 1, 1, 1, 50]"
```

## Installation
To install, specify Deque in your Podfile:

```ruby
source 'https://github.com/interfere/Specs.git'
platform :ios, '8.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'Deque'
end
```

## License
Deque is available under the MIT license. See the [LICENSE](https://github.com/interfere/Deque/blob/master/LICENSE) file for more info.

