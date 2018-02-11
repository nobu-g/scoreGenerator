//
//  BitmapBuffer.swift
//  scoreGenerator
//
//  Created by 植田暢大 on 2018/01/20.
//  Copyright © 2018年 植田暢大. All rights reserved.
//

import Foundation
import UIKit

// 画像からRGB値を抽出する
class BitmapBuffer {
    private var pixelData: Data
    let width: Int
    let height: Int
    private let bytesPerRow: Int
    private let bytesPerPixel = 4
    
    init(cgImage: CGImage) {
        //自分が望む形式でCGContextを作成する
        width = cgImage.width
        height = cgImage.height
        let colorSpace = cgImage.colorSpace!
        bytesPerRow = bytesPerPixel * width
        pixelData = Data(count: height * bytesPerRow)
        let bitsPerComponent = 8
        pixelData.withUnsafeMutableBytes {(rawData: UnsafeMutablePointer<UInt8>)->Void in
            let context = CGContext(data: rawData,
                                    width: width,
                                    height: height,
                                    bitsPerComponent: bitsPerComponent,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
    
//    convenience init?(uiImage: UIImage) {
//        if let cgImage = uiImage.cgImage {
//            self.init(cgImage: cgImage)
//        } else {
//            return nil
//        }
//    }
    
    private func getColor(x: Int, y: Int) -> UIColor {
        let pixelInfo = bytesPerRow * y + x * bytesPerPixel
        let r = CGFloat(pixelData[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(pixelData[pixelInfo+1]) / CGFloat(255.0)
        let b = CGFloat(pixelData[pixelInfo+2]) / CGFloat(255.0)
        let a = CGFloat(pixelData[pixelInfo+3]) / CGFloat(255.0)
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    subscript (x: Int) -> RGB {
        return RGB(uiColor: getColor(x: width - judgeLineY, y: x))
    }
}

// RGB値を扱うクラス
class RGB {
    let red: Int
    let green: Int
    let blue: Int
    var hasChroma: Bool {       // 有彩色かどうか
        return max(red, green, blue) - min(red, green, blue) > 50
    }
    var major: Int {
        return max(red, green, blue)
    }
    var minor: Int {
        return min(red, green, blue)
    }
    var tuple: (Int, Int, Int) {    // デバッグ用
        return (red, green, blue)
    }

    init(R red: Int, G green: Int, B blue: Int) {
        self.red   = red
        self.green = green
        self.blue  = blue
    }
    init(R red: Double, G green: Double, B blue: Double) {
        self.red   = Int(red.rounded())
        self.green = Int(green.rounded())
        self.blue  = Int(blue.rounded())
    }
    init(uiColor: UIColor) {
        let components = uiColor.cgColor.components!
        self.red   = Int(components[0] * 255)
        self.green = Int(components[1] * 255)
        self.blue  = Int(components[2] * 255)
    }
    
    static func + (rgb1: RGB, rgb2: RGB) -> RGB {
        return RGB(R: rgb1.red + rgb2.red, G: rgb1.green + rgb2.green, B: rgb1.blue + rgb2.blue)
    }
    static func / (rgb: RGB, d: Int) -> RGB {
        return RGB(R: Double(rgb.red) / Double(d), G: Double(rgb.green) / Double(d), B: Double(rgb.blue) / Double(d))
    }
}










