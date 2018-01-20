//
//  ViewController.swift
//  scoreGenerator
//
//  Created by 植田暢大 on 2018/01/19.
//  Copyright © 2018年 植田暢大. All rights reserved.
//

import UIKit
import AVFoundation
import AssetsLibrary

class ViewController: UIViewController, UIGestureRecognizerDelegate {

    var frame = 0
    var generator: AVAssetImageGenerator!
    var imageView = UIImageView()   // 静止画用のImageView
    var timer: Timer!
    

    
//    @objc func tapped(_ sender: UITapGestureRecognizer){
//        while(frame <= 1000) {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0/60) {
//                let interval = CMTimeMake(Int64(self.frame), 60)
//                var actual = CMTimeMake(Int64(0), 60)
//                // 動画の指定した時間での画像を得る(今回は動画の最後のキャプチャを撮る).
//                let capturedImage = try! self.generator.copyCGImage(at: interval, actualTime: &actual)
//                self.imageView.image = UIImage(cgImage: capturedImage)
//
//                self.frame += 1
//
//                print("タップ\(CMTimeGetSeconds(actual))")
//            }
//        }
//    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("viewDidLoad")
//        let tapGesture:UITapGestureRecognizer = UITapGestureRecognizer(
//            target: self,
//            action: #selector(ViewController.tapped(_:)))
//
//        // デリゲートをセット
//        tapGesture.delegate = self
//
//        self.view.addGestureRecognizer(tapGesture)
        // パスからassetを生成.
        let path = Bundle.main.path(forResource: "READY!!", ofType: "MP4")
        let fileURL = URL(fileURLWithPath: path!)
        let avAsset = AVURLAsset(url: fileURL, options: nil)
        
        // assetから画像をキャプチャーする為のジュネレーターを生成.
        generator = AVAssetImageGenerator(asset: avAsset)
        generator.maximumSize = self.view.frame.size
        generator.requestedTimeToleranceAfter = kCMTimeZero
        generator.requestedTimeToleranceBefore = kCMTimeZero
    
        // 静止画用のImageViewを生成.
        imageView = UIImageView(frame: self.view.frame)
        
        // imageViewをviewに追加.
        self.view.addSubview(imageView)
  
        
        
        // 線を引く
        
        // イメージ処理の開始
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 1.0)
        // パスの初期化
        let drawPath = UIBezierPath()
        drawPath.move(to: CGPoint(x: 70, y: 100))
        drawPath.addLine(to: CGPoint(x: 70, y: 700))
        // 線の色
        UIColor.yellow.setStroke()
        // 線を描く
        drawPath.stroke()
        
        // イメージコンテキストから UIImage を作る
        let drawImage = UIGraphicsGetImageFromCurrentImageContext()
        // イメージ処理の終了
        UIGraphicsEndImageContext()
        
        // イメージビューに設定する
        let drawView = UIImageView(image: drawImage)
        // 画面に表示する
        view.addSubview(drawView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        timer = Timer.scheduledTimer(timeInterval: 1/60, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        timer.fire()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        timer.invalidate()
    }
    
    @objc func update(tm: Timer) {
        let interval = CMTimeMake(Int64(self.frame), 60)
        var actual = CMTimeMake(Int64(0), 60)
        // 動画の指定した時間での画像を得る
        let capturedImage = try! self.generator.copyCGImage(at: interval, actualTime: &actual)
        self.imageView.image = UIImage(cgImage: capturedImage)
        
        if let pixelBuffer = BitmapBuffer(uiImage: UIImage(cgImage: capturedImage)) {
            let components = pixelBuffer[200, 300].cgColor.components!
            let red = components[0] * 255
            let green = components[1] * 255
            let blue = components[2] * 255
            
            print("red: \(red)  green: \(green)  blue: \(blue)")
        }
        
        
        
        
        
        self.frame += 1
//        print("タップ\(CMTimeGetSeconds(actual))")
    }


   
    
}

