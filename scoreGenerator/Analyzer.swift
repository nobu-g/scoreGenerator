//
//  Analyzer.swift
//  scoreGenerator
//
//  Created by 植田暢大 on 2018/01/21.
//  Copyright © 2018年 植田暢大. All rights reserved.
//

import Foundation

let judgeLineY = 311                        // 判定線のy座標
fileprivate let sideMargin = 99             // 両端判定円から画面端までの距離
fileprivate let circlePitch = 81.6          // 判定円の間隔
fileprivate let diameter = 61               // 判定円の直径
fileprivate let radius = 30                 // 判定円の半径
fileprivate let bpm = 178.0                 // 解析譜面のBPM

private var notes = [Note]()                // 解析結果を格納

extension Array {
    public mutating func append(_ newElements: [Array.Element]) {
        for element in newElements {
            append(element)
        }
    }
}

class Analyzer {
    
    enum Status {
        case idle, detecting
    }

    private var status = [Status](repeating: .idle, count: 6)               // 単ノーツ検出中か(レーン毎にある)
    private var detectingBuf = [[CutEnd]](repeating: [CutEnd](), count: 6)  // 単ノーツdetect結果を格納
    private var longSample1: LongSample?
    private var longSample2: LongSample?
    
    
    func update(_ pixel: BitmapBuffer, _ frame: Int) {//print(frame, terminator: ":")
        
        var lanesToSearch = [0, 1, 2, 3, 4, 5]  // 単ノーツを探索するべきレーン(ロングがある場合削られる)
        
        // ロングノーツがあるなら探索。探索終了したならnilに戻す
        if longSample1?.update(pixel, frame) == false {
            longSample1 = nil
        }
        if longSample2?.update(pixel, frame) == false {
            longSample2 = nil
        }

        // ロングノーツがかぶさっているレーンは探索しない
        longSample1?.laneFilter(&lanesToSearch)
        longSample2?.laneFilter(&lanesToSearch)

        for lane in lanesToSearch {
            
            let leftEdgeOfCircle = sideMargin + Int(circlePitch * Double(lane))
            switch status[lane] {
            case .idle:
                // ノーツ断面が見つかった時
                if let cut = CutEnd(pixel, from: leftEdgeOfCircle, to: leftEdgeOfCircle + diameter, frame) { //print(cut.color.tuple)  // 判定円の左端から中心まで走査
                    detectingBuf[lane].append(cut)
                    status[lane] = .detecting
                }
            case .detecting:
                if let cut = CutEnd(pixel, from: leftEdgeOfCircle, to: leftEdgeOfCircle + diameter, frame) { //print(cut.color.tuple) // 判定円の左端から中心まで走査
                    if detectingBuf[lane].last!.isTap && cut.isFootOfLong {   // タップノーツ検出中に単ノーツ以外の色(ロング根元色)が検出された場合
                        if !cut.isJoint {
                            // 単ノーツの後にはロングノーツが続いていた
                            let notesBuf = Analyzer.constructNote(from: detectingBuf[lane], lane: lane)
                            detectingBuf[lane].removeAll()
                            notes.append(notesBuf)
                            print("\(lane): ロング開始")
                            // LongSampleのインスタンスを生成してロングノーツ観測開始
                            if !notesBuf.isEmpty {
                                if longSample1 == nil {
                                    longSample1 = LongSample(startNote: notesBuf.last!)
                                } else if longSample2 == nil {
                                    longSample2 = LongSample(startNote: notesBuf.last!)
                                } else {
                                    print("3本目のロングノーツを検出(\(frame / 60)s)")
                                }
                                status[lane] = .idle
                            } else {
                                print("始点ノーツ構成に失敗")
                            }
                        }
                    } else {
                        detectingBuf[lane].append(cut)
                    }
                } else {
                    // 単ノーツ検出終了
                    notes.append(Analyzer.constructNote(from: detectingBuf[lane], lane: lane))
                    print("\(lane): 単ノーツ")
                    detectingBuf[lane].removeAll()
                    status[lane] = .idle
                }
            }
        }
    }
    
    
    // ノーツ断面の集合からノーツを構成する(複数ノーツが重なっていた時は切り分ける)
    fileprivate static func constructNote(from cuts: [CutEnd], lane: Int) -> [Note] {
        guard !cuts.isEmpty else {
            return [Note]()
        }
        
        // 切り分け
        var cutSets = [[CutEnd]]()
        
        var isNeck = [false]
        var cut0 = cuts.first!
        var diff0 = 1
        for cut in cuts.dropFirst() {
            let diff = cut.width - cut0.width
            // くびれ発見
            if diff0 < 0 && diff > 0 {
                isNeck.append(true)
            } else {
                isNeck.append(false)
            }
            
            cut0 = cut
            diff0 = diff
        }
        var startIndex = 0
        for (index, _) in cuts.enumerated() {
            if isNeck[index] {
                cutSets.append(cuts[startIndex...(index-2)].map { $0 } )
                startIndex = index
            }
        }
        cutSets.append(cuts[startIndex...].map { $0 } )
        
        let noteRadius = 31.5
//        let noteRadiusLarge = 45.0
        var notes = [Note]()
        // 各セットからノーツを構成
        for cutSet in cutSets {
            guard !cutSet.isEmpty else {
                return [Note]()
            }
            
            // フリックノーツかどうか
            let isFlick = !cutSet.first!.isTap
            // 大ノーツかどうか
            var isLarge = (Double(cutSet.map { $0.width }.max()!) > noteRadius * 2) && !isFlick
            if !isLarge && !isFlick {       // 大ノーツ見過ごしを防ぐ
                for cut in cutSet {
                    if cut.isJoint {
                        isLarge = true
                    }
                }
            }
            
            let frame = cutSet.sorted(by: { $0.width > $1.width }).first!.frame
            notes.append(Note(beat: Double(frame) / 3600 * bpm, lane: lane, flick: isFlick, large: isLarge));print(frame/60)

//            if cutSet.count == 1 {
//                notes.append(Note(beat: Double(cutSet.first!.frame) / 3600 * bpm, lane: lane, flick: isFlick, large: isLarge))
//            } else {
//                /* 楕円 x^2 + ((y-q)/b)^2 = r^2 を仮定 */
//                /* 中間の2点からパラメータqを推定 */
//                let r = isLarge ? noteRadiusLarge : noteRadius  // ノーツ円半径
//                let cut0 = cutSet.first!
//                let cut1 = cutSet.last!
//                let x0 = Double(cut0.width) / 2
//                let x1 = Double(cut1.width) / 2
//                let y0 = 0.0
//                let y1 = Double(10 * (cut1.frame - cut0.frame))     // xに合わせてスケール変換(必須ではない)
//                let A = sqrt(r * r - x0 * x0) / sqrt(r * r - x1 * x1)
//                let q = (A * y1 - y0) / (A - 1)
//                let frame = q / 10 + Double(cut0.frame)
//                notes.append(Note(beat: frame / 3600 * bpm, lane: lane, flick: isFlick, large: isLarge));print(frame/60)
//            }
        }
        
        return notes
    }
    
    
    // 解析終了時の処理(ファイル書き出しなど)
    func finish() {
        let offset = 4.0    // 音楽と譜面のずれを補正(拍指定)
        
        // middle刈り
        for note in notes {
            if var next0 = note.next {
                while next0.next != nil {
                    let next1 = next0.next!
                    if note.lane == next0.lane {
                        if next0.lane == next1.lane {
                            note.next = next1
                        }
                    } else {
                        if next1.lane == next0.lane * 2 - note.lane {
                            // beat条件
                            if abs(next1.beat - (next0.beat * 2 - note.beat)) <= 1 {
                                note.next = next1
                            }
                        }
                    }
                    next0 = next1
                }
            }
        }
        // offset加算
        for note in notes {
            note.beat += offset
            var following = note
            while(following.next != nil) {
                following = following.next!
                following.beat += offset
            }
        }
        // 1/4拍刻みにノーツを整列させる
        var adjust = 0.0
        var minError = 1000.0
        for adj in stride(from: 0, to: 60/bpm/4, by: 60/bpm/4/20) {
            var error = 0.0
            for beat in notes.map ({ $0.beat + adj }) {
                error += abs(beat - (beat * 4).rounded(.toNearestOrEven) / 4)
            }
            if error < minError {
                minError = error
                adjust = adj
            }
        }
        for note in notes {
            note.beat = ((note.beat + adjust) * 4).rounded(.toNearestOrEven) / 4
            var following = note
            while(following.next != nil) {
                following = following.next!
                following.beat = ((following.beat + adjust) * 4).rounded(.toNearestOrEven) / 4
            }
        }
        
        
        /* bmsファイルへ書き出し */
        var bmsData =
        """
        
        *---------------------- HEADER FIELD
        
        #BPM \(bpm)
        
        
        #LNTYPE 1
        
        #WAV01 タップ.mp3
        #WAV02 フリック.mp3
        #WAV03 始め１.mp3
        #WAV04 途中１.mp3
        #WAV05 離し１.mp3
        #WAV06 フリック離し１.mp3
        #WAV07 始め２.mp3
        #WAV08 途中２.mp3
        #WAV09 離し２.mp3
        #WAV0A フリック離し２.mp3
        #WAV10 SAKURAスキップ.mp3
        
        
        *---------------------- MAIN DATA FIELD
        
        
        """
        
        // 必要な小節数を求める
        var beat1 = 0.0
        var beat2 = 0.0
        var beat3 = 0.0
        for note in notes.reversed() {
            if note.next != nil {
                var end = note.next!
                while end.next != nil { end = end.next! }
                if beat1 == 0.0 {
                    beat1 = end.beat
                } else if beat2 == 0.0 {
                    beat2 = end.beat
                    if beat3 > 0.0 { break }
                }
            } else {
                if beat3 == 0.0 {
                    beat3 = note.beat
                    if beat1 > 0.0 && beat2 > 0.0 { break }
                }
            }
        }
        let barNum = Int(max(beat1, beat2, beat3) / 4) + 1
        
        // notesをbeat毎に配列の要素に仕分け
        var barGroup = [[Note]](repeating: [Note](), count: barNum)
        for note in notes {
            barGroup[Int(note.beat / 4)].append(note)
            var following = note
            while(following.next != nil) {
                following = following.next!
                barGroup[Int(following.beat / 4)].append(following)
            }
        }
        
        // typeを設定
        var endBeat1 = 0.0
        var endBeat2 = 0.0
        for note in notes {
            if note.next == nil {
                note.type = .single
                continue
            }
            
            if note.beat > endBeat1 {
                note.type = .start1
            } else if note.beat > endBeat2 {
                note.type = .start2
            }
            var following = note.next!
            while true {
                if following.next != nil {
                    if note.type == .start1 {
                        following.type = .middle1
                    } else if note.type == .start2 {
                        following.type = .middle2
                    }
                    following = following.next!
                } else {
                    if note.type == .start1 {
                        following.type = .end1
                        endBeat1 = following.beat
                    } else if note.type == .start2 {
                        following.type = .end2
                        endBeat2 = following.beat
                    }
                    break
                }
            }
        }

        // 各要素でレーンごとに分け、書き出していく
        let channelMap = [11, 12, 13, 15, 18, 19]       // レーンとチャンネルの対応付け
        for (bar, group) in barGroup.enumerated() {
            for lane in 0...5 {
                let laneGroup = group.filter { $0.lane == lane }
                if !laneGroup.isEmpty {
                    bmsData += String(format: "#%03d%02d:", bar, channelMap[lane])
                    var kmin = 2
                    for i in (-2...2).reversed() {
                        if
                        laneGroup.filter ({ note in
                            let beat = note.beat * pow(2, Double(i))
                            return beat != beat.rounded()
                        }).isEmpty
                        { kmin = i }
                    }
                    let divNum = Int(pow(2, Double(kmin + 2)))     // 分割数(1~16)
                    for i in 0..<divNum {
                        var ob: Note?
                        for note in laneGroup {
                            let beatPos = Double(bar) * 4 + 4 / Double(divNum) * Double(i)
                            if note.beat == beatPos {
                                ob = note
                            }
                        }
                        if ob == nil {
                            bmsData += "00"
                        } else {
                            switch ob!.type {
                            case .single:
                                bmsData += ob!.isFlick ? "02" : "01"
                            case .start1:
                                bmsData += "03"
                            case .middle1:
                                bmsData += "04"
                            case .end1:
                                bmsData += ob!.isFlick ? "06" : "05"
                            case .start2:
                                bmsData += "07"
                            case .middle2:
                                bmsData += "08"
                            case .end2:
                                bmsData += ob!.isFlick ? "0A" : "09"
                            }
                        }
                    }
                    bmsData += "\r\n"
               }
            }
            bmsData += "\r\n"
        }
        
        print(bmsData)
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let path_file_name = dir.appendingPathComponent("READY!!.bms")
            do {
                try bmsData.write( to: path_file_name, atomically: false, encoding: String.Encoding.shiftJIS )
            } catch let error as NSError {
                print("Failed to write\n\(error)")
            }
        }
    }
}


// ノーツの断面を扱う
class CutEnd {
    private let pixel: BitmapBuffer     // 各点のビットマップデータ
    private(set) var frame: Int         // フレーム数
    private(set) var color: RGB         // 見つかった断面の色
    private(set) var leftEnd = 0        // 見つかった断面の左端座標
    private      var rightEnd = 0       // 見つかった断面の右端座標
    private(set) var width = 0          // ノーツ断面の幅

    // タップノーツかフリックか色で判断(タップならtrue)
    var isTap: Bool {
        // 60はタップの赤と右フリックの黄のR-Gの閾値
        return color.major == color.red && (color.red - color.green > 60)
    }
    // 両端どちらかの色が単ノーツではなくロングノーツ(初期)かどうか
    var isFootOfLong: Bool {
        return isFootOfLong(color: pixel[leftEnd]) || isFootOfLong(color: pixel[rightEnd])
    }
    // 単ノーツとロングノーツの接続点かどうか
    var isJoint: Bool {
        // 有彩色無彩色有彩色のパターンがあればtrue
        for posX in leftEnd...rightEnd {
            if pixel[posX].isAchromatic {
                return true
            }
        }
        return false
    }
    
    // 判定線上の走査を行う
    init?(_ pixel: BitmapBuffer, from start: Int, to end: Int, _ frame: Int) {
        self.pixel = pixel
        self.frame = frame
        
        var colorBuf = [RGB]()
        
        // 右端点を走査
        var posX = start
        while(!pixel[posX].hasChroma) {
            if posX == end {
                break
            }
            posX += 1
        }
        // 有彩色点が見つかった場合
        if posX < end {
            self.leftEnd = posX
            // 左端点も走査
            posX = end
            while(!pixel[posX].hasChroma) {
                posX -= 1
            }
            self.rightEnd = posX
            self.width = rightEnd - leftEnd + 1
            
            for posX in leftEnd...rightEnd {
                if pixel[posX].hasChroma {
                    colorBuf.append(pixel[posX])
                }
            }
            // 見つかった有彩色点の色の平均をメンバに設定
            self.color = colorBuf.reduce(RGB(R: 0, G: 0, B: 0), +) / colorBuf.count
        } else {        // 有彩色点が見つからなかった時(判定線上にノーツがなかった時)
            return nil
        }
    }
    
    // 色が単ノーツではなくロングノーツ(初期)かどうか
    private func isFootOfLong(color: RGB) -> Bool {
        // Gが最大かつRとBの和が300より大きいか、Bが最大かつGとBの差が15より小さければロングノーツ
        return (color.major == color.green && color.red  + color.blue  > 300)
            || (color.major == color.blue  && color.blue - color.green < 15)
    }
}


// ロング検出用クラス
class LongSample {
    private var parent: Note                // ロング根元のノーツ(middleの可能性もある)
//    private var leftEnd0: Int               // 2つ前のサンプルの左端座標
    private var preLeftEnd: Int             // 1つ前のサンプルの左端座標
    private var preWidth = 0                // 1つ前のサンプルの幅
    private var preLane: Int?               // ロングノーツが乗っていたレーン
    private var hasRegistered = true        // middleノーツを登録し終えたかどうか
    private var preDistance = -1.0          // 1つ前のサンプルの判定円中心との距離(hasRegisteredがfalseの時のみ有効)
    private var isPreStill = false          // 前回とサンプル位置が変わらないか
    private var terminalCuts = [CutEnd]()   // 終端ノーツの断面
    private var isTerminal = false          // ノーツ終端検出中か
    
    
    init(startNote: Note) {
        self.parent = startNote
        self.preLeftEnd = -1          // 無効
        self.preLane = startNote.lane
    }
    
    
    fileprivate func update(_ pixel: BitmapBuffer, _ frame: Int) -> Bool {
        // ロングノーツのスライド移動も考えて左右15ピクセルまで探索(STANDING ALIVE基準)
        let start = (preLeftEnd >= 15) ? preLeftEnd - 15 : sideMargin + Int(circlePitch * Double(parent.lane)) - 15
        let end   = (preLeftEnd >= 15) ? preLeftEnd + preWidth + 15 : sideMargin + Int(circlePitch * Double(parent.lane)) + diameter + 15
        if let cut = CutEnd(pixel, from: start, to: end, frame) {
            // 終端判定、フラグ更新
            if (preWidth > 0 && abs(cut.width - preWidth) > 10) || cut.isJoint {
                isTerminal = true
            }
            
            let isStill = (cut.leftEnd == preLeftEnd)
            // まっすぐのロングノーツが折れた時
            if isPreStill && !isStill {
                // middle生成
                let middlePos = Double(preLeftEnd) + Double(preWidth) / 2
                let lane = Int(((middlePos - Double(sideMargin + radius)) / circlePitch).rounded())
                parent.next = Note(beat: (Double(frame) - 0.5) / 3600 * bpm, lane: lane)
                parent = parent.next!
                print("\(lane): ミドル")
            }
            
            // 今どのレーン上にいるか
            var nowLane: Int?
            for lane in 0...5 {
                let center = Double(sideMargin + radius) + circlePitch * Double(lane)
                let posX = Double(cut.leftEnd) + Double(preWidth) / 2
                let distance = abs(posX - center)
                if distance < 8 {
                    nowLane = lane
                    break
                }
            }
            
            // スライド移動した場合
            if nowLane != nil && nowLane != preLane {
                hasRegistered = false
            }
            if !hasRegistered {
                var distance = 8.0
                if nowLane != nil {
                    let center = Double(sideMargin + radius) + circlePitch * Double(nowLane!)
                    let posX = Double(cut.leftEnd) + Double(preWidth) / 2
                    distance = abs(posX - center)
                }
                // 未登録状態で、初めてじゃないとき
                if hasRegistered == false && preDistance >= 0 {
                    if distance >= preDistance {
                        // middle生成
                        parent.next = Note(beat: (Double(frame) - 0.5) / 3600 * bpm, lane: preLane!)
                        parent = parent.next!
                        print("\(preLane!): ミドル")
                        hasRegistered = true
                        distance = -1.0
                    }
                }
                preDistance = distance
            }

            
            
//                let expectedLeftEnd = 2 * leftEnd1 - leftEnd0
//                // ロングノーツが途中で折れている場合、middleノーツとして登録
//                if abs(cut.leftEnd - expectedLeftEnd) > 10 && !isTerminal {
//                    let middlePos = Double(cut.leftEnd) + Double(width) / 2
//                    let lane = Int(((middlePos - Double(sideMargin + radius)) / circlePitch).rounded())
//                    parent.next = Note(beat: (Double(frame) - 0.5) / 3600 * bpm, lane: lane)
//                    parent = parent.next!
//                    print("\(lane): ミドル")
//                    leftEnd1 = -1   // 無効化
//                }
            
            
            // 終端ノーツのみがdetectされていればcutをバッファに保存
            if isTerminal && !cut.isJoint {
                terminalCuts.append(cut)
            }
            
            isPreStill = isStill
            preLane = nowLane
            preLeftEnd = cut.leftEnd
            preWidth = cut.width
        } else {                // ノーツ断面が見つからなかった時
            // 偶然ロングノーツと終端ノーツの隙間を走査してしまい、detectされないことがあるかも
            guard !terminalCuts.isEmpty else {
                isTerminal = true
                return true
            }
            
            let middlePos = Double(terminalCuts.last!.leftEnd) + Double(terminalCuts.last!.width) / 2
            let lane = Int(((middlePos - Double(sideMargin + radius)) / circlePitch).rounded())
            let noteBuf = Analyzer.constructNote(from: terminalCuts, lane: lane)
            if noteBuf.isEmpty {
                print("終端ノーツ構成に失敗")
            } else {
                parent.next = noteBuf.first!
                notes.append(noteBuf.dropFirst().map { $0 } )
                print("\(lane): ロング終了")
            }
            
            return false  // ロング探索終了のお知らせ
        }
        
        return true
    }
    
    
    // ロングノーツが被っている判定円をフィルタリング
    func laneFilter(_ lanes: inout [Int]) {
        lanes = lanes.filter { (lane) in
            let leftEdgeOfCircle = sideMargin + Int(circlePitch * Double(lane))
            if (preLeftEnd + preWidth < leftEdgeOfCircle) || (leftEdgeOfCircle + diameter < preLeftEnd) {
                return true
            } else {
                return false
            }
        }
    }
}


// 各ノーツを表す
class Note {
    enum NoteType {
        case start1, middle1, end1, start2, middle2, end2, single
    }
    
    var next: Note?
    var beat: Double
    let lane: Int
    let isFlick: Bool
    let isLarge: Bool
    var type = NoteType.single  // Analyzer.finish()関数で使う
    
    init(beat: Double, lane: Int, flick isFlick: Bool = false, large isLarge: Bool = false) {
        self.beat = beat
        self.lane = lane
        self.isFlick = isFlick
        self.isLarge = isLarge
    }
}
