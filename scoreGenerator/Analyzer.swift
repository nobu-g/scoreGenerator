//
//  Analyzer.swift
//  scoreGenerator
//
//  Created by 植田暢大 on 2018/01/21.
//  Copyright © 2018年 植田暢大. All rights reserved.
//

import Foundation

class Analyzer {
    
    enum Status {
        case idle, detecting
    }
    
    static let judgeLineY = 311     // 判定線のy座標
    private let sideMargin = 99     // 両端判定円から画面端までの距離
    private let circlePitch = 81.6  // 判定円の間隔
    private let diameter = 61       // 判定円の直径
    private let radius: Int         // 判定円の半径
    private let bpm = 174.0         // 解析譜面のBPM
    
    private var status = [Status](repeating: .idle, count: 6)   // ノーツ検出中か(レーン毎にある)
    private var detectingBuf = [[(width: Int, frame: Int)]](repeating: [(Int, Int)](), count: 6)    // detect結果を格納

    private var notes = [Note]()    // 解析結果を格納
    
    init() {
        radius = (diameter - (diameter % 2)) / 2
    }
    
    func update(_ pixel: BitmapBuffer, _ frame: Int) {print(frame, terminator: ":")
        for lane in 0..<6 {
            var isFound = false
            let leftEdgeOfCircle = sideMargin + Int(circlePitch * Double(lane))
            var detectedWidth = 0
            // 判定円の左端から中心まで走査
            for posX in leftEdgeOfCircle...(leftEdgeOfCircle + radius) {
                let components = pixel[posX].cgColor.components!
                let red = components[0] * 255
                let green = components[1] * 255
                let blue = components[2] * 255
                
//                print("red: \(red)  green: \(green)  blue: \(blue)")
                if max(red, green, blue) - min(red, green, blue) > 40 {
                    print(lane)
                    isFound = true
                    detectedWidth = (leftEdgeOfCircle + radius - posX) * 2 + 1
                    break
                }
            }
            
            switch status[lane] {
            case .idle:
                if isFound {
                    detectingBuf[lane].append((detectedWidth, frame))
                    status[lane] = .detecting
                }
            case .detecting:
                if isFound {
                    detectingBuf[lane].append((detectedWidth, frame))
                } else {
                    let buf = detectingBuf[lane]
                    var frame = 0.0         // ノーツが判定線に乗ったときのフレーム
                    if buf.count % 2 == 1 {
                        frame = Double(buf[(buf.count - 1)/2].frame)
                    } else {
                        frame = Double(buf[buf.count/2 - 1].frame + buf[buf.count/2].frame) / 2
                    }
                    
                    notes.append(Note(beat: frame / 3600 * bpm, lane: lane))
                    
                    status[lane] = .idle
                }
            }
        }
    }
    
    // 解析終了時の処理(ファイル書き出しなど)
    func finish() {
        for note in notes {
            note.beat = (note.beat * 4).rounded(.toNearestOrEven) / 4
        }
    }
}

class Note {
    var beat: Double
    var lane: Int
    
    init(beat: Double, lane: Int) {
        self.beat = beat
        self.lane = lane
    }
}








