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

class ViewController: UIViewController/*, UIGestureRecognizerDelegate*/ {

    var frame = 0                           // 現在のフレーム数(60fps)
    var duration: CMTime = kCMTimeZero      // 動画の長さ
    var generator: AVAssetImageGenerator!   // assetから画像をキャプチャーする為のジュネレーター
    var imageView = UIImageView()           // 静止画用のImageView
    let analyzer = Analyzer()               // 動画からキャプチャした画像のアナライザ
    var timer: Timer!
   
    
    // 毎フレーム呼ばれる
    @objc func update(tm: Timer) {
        
        let interval = CMTimeMake(Int64(self.frame), 60)
        guard interval < duration else {
            // 解析終了
            analyzer.finish()
            timer.invalidate()
            print("解析終了")
            return
        }
        
        // 動画の指定した時間での画像を得る
        let capturedImage = try! self.generator.copyCGImage(at: interval, actualTime: nil)
        self.imageView.image = UIImage(cgImage: capturedImage, scale: 1.0, orientation: UIImageOrientation.left)
        
        // 画像を解析
        analyzer.update(BitmapBuffer(cgImage: capturedImage), frame)
        
        self.frame += 1
    }

//    func drawLine() -> UIImage? {
//        // イメージ処理の開始
//        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 1.0)
//        // パスの初期化
//        let drawPath = UIBezierPath()
//        drawPath.move(to: CGPoint(x: 99, y: judgeLineY))
//        drawPath.addLine(to: CGPoint(x: 568, y: judgeLineY))
//        // 線の色
//        UIColor.yellow.setStroke()
//        // 線幅
//        drawPath.lineWidth = 1.0
//        // 線を描く
//        drawPath.stroke()
//
//        // イメージコンテキストから UIImage を作る
//        let image = UIGraphicsGetImageFromCurrentImageContext()
//        // イメージ処理の終了
//        UIGraphicsEndImageContext()
//
//        return image
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
        let path = Bundle.main.path(forResource: "READY!!", ofType: "MOV")
        let fileURL = URL(fileURLWithPath: path!)
        let avAsset = AVURLAsset(url: fileURL, options: nil)
        
        self.duration = avAsset.duration
        
        // assetから画像をキャプチャーする為のジュネレーターを生成.
        generator = AVAssetImageGenerator(asset: avAsset)
        generator.maximumSize = CGSize(width: self.view.frame.size.height, height: self.view.frame.width)
        generator.requestedTimeToleranceAfter = kCMTimeZero
        generator.requestedTimeToleranceBefore = kCMTimeZero
    
        // 静止画用のImageViewを生成.
        imageView = UIImageView(frame: self.view.frame)
        // imageViewをviewに追加.
        self.view.addSubview(imageView)
  
        
//        // 線を引く
//        if let drawImage = drawLine() {
//            // イメージビューに設定する
//            let drawView = UIImageView(image: drawImage)
//            // 画面に表示する
//            view.addSubview(drawView)
//        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        timer = Timer.scheduledTimer(timeInterval: 1/60, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        timer.invalidate()
    }
}


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


//    func drawLine(_ color: UIColor, _ posX: Int) -> UIImage? {
//        // イメージ処理の開始
//        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 1.0)
//        // パスの初期化
//        let drawPath = UIBezierPath()
//        drawPath.move(to: CGPoint(x: posX, y: Analyzer.judgeLineY))
//        drawPath.addLine(to: CGPoint(x: posX+1, y: Analyzer.judgeLineY))
//        // 線の色
//        color.setStroke()
//        // 線幅
//        drawPath.lineWidth = 1.0
//        // 線を描く
//        drawPath.stroke()
//
//        // イメージコンテキストから UIImage を作る
//        let image = UIGraphicsGetImageFromCurrentImageContext()
//        // イメージ処理の終了
//        UIGraphicsEndImageContext()
//
//        return image
//    }




