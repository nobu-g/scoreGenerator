//
//  BitmapBuffer.swift
//  scoreGenerator
//
//  Created by 植田暢大 on 2018/01/20.
//  Copyright © 2018年 植田暢大. All rights reserved.
//

import Foundation
import UIKit

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
    
    subscript (x: Int) -> UIColor {
        return getColor(x: width - Analyzer.judgeLineY, y: x)
    }
}
