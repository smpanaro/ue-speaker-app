import UIKit

var x: UInt64 = 0x0201ae

var bytes = [UInt8]()
while (x != 0) {
    let lo = UInt8(x & 255)
    bytes.append(lo)
    x = x >> 8
}
print(bytes)
