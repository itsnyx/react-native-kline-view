//
//  HTDrawManyPoint.swift
//  CocoaAsyncSocket
//
//  Created by hublot on 2020/9/4.
//

import UIKit

enum HTDrawType: Int {
    
    case none = 0
    
    case line = 1

    case horizontalLine = 2

    case verticalLine = 3

    case halfLine = 4

    case parallelLine = 5

    // Global price-level horizontal line (spans entire chart horizontally, 1 anchor point)
    case globalHorizontalLine = 301

    // Global price-level horizontal line with text (left) and price (right) labels
    case globalHorizontalLineWithLabel = 303

    // Single-candle marker with label bubble and pointer to a candle
    case candleMarker = 304

    // Global time-level vertical line (spans entire chart vertically, 1 anchor point)
    case globalVerticalLine = 302

    case rectangle = 101

    case parallelogram = 102

    // Text annotation at a single anchor point
    case text = 201
    
    // 最多可以有多少个点, 超过就直接跳到下一次绘画
    var count: Int {
        switch self {
        case .line, .horizontalLine, .verticalLine, .halfLine, .rectangle:
            return 2
        case .parallelLine, .parallelogram:
            return 3
        // text & other types use a single anchor point
        default:
            return 1
        }
    }
    
}


class HTDrawItem: NSObject {
    
    /// Stable unique identifier for this drawing, used by JS to track items
    /// even when their array index changes (e.g. after deletions).
    let uid: String

    var drawType = HTDrawType.none
    
    var drawColor = UIColor.init(red: 0.27, green: 0.37, blue: 1, alpha: 1)
    
    var drawLineHeight: CGFloat = 1
    
    var drawDashWidth: CGFloat = 1
    
    var drawDashSpace: CGFloat = 1
    
    var drawIsLock = false

    // Optional text for text-annotation draw type
    var text: String = ""
    
    // Text styling
    var textColor = UIColor.white
    
    var textBackgroundColor = UIColor.black.withAlphaComponent(0.6)
    
    var textCornerRadius: CGFloat = 8
    
    // Optional per-item font size for text annotations.
    // When 0, the renderer will fall back to configManager.candleTextFontSize.
    var textFontSize: CGFloat = 0
    
    var pointList = [CGPoint]()
    
    var touchMoveIndexList = [Int]()
    
    init(_ drawType: HTDrawType, _ startPoint: CGPoint, uid: String? = nil) {
        self.uid = uid ?? UUID().uuidString
        self.drawType = drawType
        self.pointList = [startPoint]
    }
    
    // 找到谁正在被拖动
    static func findTouchMoveItem(_ drawItemList: [HTDrawItem]) -> HTDrawItem? {
        for drawItem in drawItemList {
            if drawItem.touchMoveIndexList.count > 0 {
                return drawItem
            }
        }
        return nil
    }
    
    // 如果是线段, 填充所有的点到 touchMoveIndexList
    static func fillAllTouchMoveItem(_ drawItem: HTDrawItem) -> Void {
        drawItem.touchMoveIndexList.removeAll()
        for (index, _) in drawItem.pointList.enumerated() {
            drawItem.touchMoveIndexList.append(index)
        }
    }
    
    // 计算某个点到另外两个点连成的线之间的垂直距离
    static func pedalPoint(p1: CGPoint, p2:CGPoint, x0: CGPoint) -> Double {
        let a = p2.y - p1.y
        let b = p1.x - p2.x
        let c = p2.x * p1.y - p1.x * p2.y
//        let x = (b * b * x0.x - a * b * x0.y - a * c) / (a * a + b * b)
//        let y = (-a * b * x0.x + a * a * x0.y - b * c) / (a * a + b * b)
        let d = abs((a * x0.x + b * x0.y + c)) / sqrt(pow(a, 2) + pow(b, 2))
//        let pt = CGPoint(x: x, y: y)
        return Double(d)
    }
    
    // 计算某个点到另一个点的距离
    static func distance(p1: CGPoint, p2:CGPoint) -> CGFloat {
        let a = p2.y - p1.y
        let b = p1.x - p2.x
        let d = sqrt(pow(a, 2) + pow(b, 2))
        return d
    }
    
    // 计算两个点的中心点
    static func centerPoint(p1: CGPoint, p2: CGPoint) -> CGPoint {
        let a = p2.x + p1.x
        let b = p1.y + p2.y
        return CGPoint.init(x: a / 2.0, y: b / 2.0)
    }
    
    static func lineListWithIndex(_ drawItem: HTDrawItem, _ index: Int, _ klineView: HTKLineView) -> [(CGPoint, CGPoint)] {
        guard index > 0, drawItem.pointList.count > index else {
            return []
        }
        var point = drawItem.pointList[index]
        let lastPoint = drawItem.pointList[index - 1]
        switch drawItem.drawType {
        case .horizontalLine:
            point.y = lastPoint.y
            drawItem.pointList[index] = point
        case .verticalLine:
            point.x = lastPoint.x
            drawItem.pointList[index] = point
        case .halfLine:
            let viewPoint = klineView.viewPointFromValuePoint(point)
            let lastViewPoint = klineView.viewPointFromValuePoint(lastPoint)
            var outPoint = viewPoint
            let xDistance = viewPoint.x - lastViewPoint.x
            let yDistance = viewPoint.y - lastViewPoint.y
            var append = UIScreen.main.bounds.size.width + UIScreen.main.bounds.size.height
            
            var k: CGFloat = 0
            if (xDistance != 0) {
                k = yDistance / xDistance
            }
            if (abs(k) > 1) {
                append *= yDistance < 0 ? -1 : 1
                if (yDistance != 0) {
                    outPoint.x += append / k
                    outPoint.y += append
                } else {
                    outPoint.x += append
                }
            } else {
                if (xDistance == 0 && yDistance < 0) {
                    append *= -1
                } else {
                    append *= xDistance < 0 ? -1 : 1
                }
                if (xDistance != 0) {
                    outPoint.x += append
                    outPoint.y += append * k
                } else {
                    outPoint.y += append
                }
            }
            return [(lastPoint, klineView.valuePointFromViewPoint(outPoint))]
        case .parallelLine:
            if index == 1 {
                return [(lastPoint, point)]
            } else if index == 2 {
                let firstPoint = drawItem.pointList[0]
                
                point.x = min(max(point.x, firstPoint.x), lastPoint.x)
                drawItem.pointList[index] = point
                
                let base = (lastPoint.x - firstPoint.x)
                var k: CGFloat = 1
                if base != 0 {
                    k = (lastPoint.y - firstPoint.y) / base
                }
                let b = point.y - point.x * k
                let previousPoint = CGPoint.init(x: lastPoint.x, y: k * lastPoint.x + b)
                let nextPoint = CGPoint.init(x: firstPoint.x, y: k * firstPoint.x + b)
                return [(previousPoint, nextPoint)]
            }
        case .rectangle:
            let previousPoint = CGPoint.init(x: point.x, y: lastPoint.y)
            let nextPoint = CGPoint.init(x: lastPoint.x, y: point.y)
            return [
                ( lastPoint, previousPoint ),
                ( previousPoint, point ),
                ( point, nextPoint ),
                ( nextPoint, lastPoint )
            ]
        case .parallelogram:
            if index == 1 {
                return [(point, lastPoint)]
            } else if index == 2 {
                let firstPoint = drawItem.pointList[0]
                
                let base = (lastPoint.x - firstPoint.x)
                var k: CGFloat = 1
                if base != 0 {
                    k = (lastPoint.y - firstPoint.y) / base
                }
                let b = point.y - point.x * k
                let nextPointX = firstPoint.x + (point.x - lastPoint.x)
                let nextPoint = CGPoint.init(x: nextPointX, y: k * nextPointX + b)
                return [
                    ( lastPoint, point ),
                    ( point, nextPoint ),
                    ( nextPoint, firstPoint ),
                ]
            }
        default:
            break
        }
        return [(point, lastPoint)]
    }
    
    static func beganFillTouchMoveItemPointMapper(_ drawItem: HTDrawItem, _ location: CGPoint, _ klineView: HTKLineView) -> Bool {
        for (index, point) in drawItem.pointList.enumerated() {
            // Special hit-testing for text annotations: allow tapping anywhere inside
            // the rendered text bubble (with a small margin), not just exactly on
            // the anchor point.
            if case .text = drawItem.drawType {
                let viewPoint = klineView.viewPointFromValuePoint(point)
                let locationViewPoint = klineView.viewPointFromValuePoint(location)

                let fontSize = drawItem.textFontSize > 0
                    ? drawItem.textFontSize
                    : klineView.configManager.candleTextFontSize
                let font = klineView.configManager.createFont(fontSize)
                let text = drawItem.text as NSString

                if !drawItem.text.isEmpty {
                    let paddingH: CGFloat = 12
                    let paddingV: CGFloat = 6
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                    ]
                    let textSize = text.size(withAttributes: attributes)
                    let bubbleRect = CGRect(
                        x: viewPoint.x,
                        y: viewPoint.y,
                        width: textSize.width + paddingH * 2,
                        height: textSize.height + paddingV * 2
                    ).insetBy(dx: -10, dy: -10) // extra tap margin

                    if bubbleRect.contains(locationViewPoint) {
                        drawItem.touchMoveIndexList = [index]
                        return true
                    }
                }
            }

            // Hit-testing for global horizontal/vertical lines: allow tapping anywhere
            // along the line (with a generous margin), not just the anchor point.
            if drawItem.drawType == .globalHorizontalLine ||
                drawItem.drawType == .globalHorizontalLineWithLabel {
                let anchor = klineView.viewPointFromValuePoint(point)
                let loc = klineView.viewPointFromValuePoint(location)
                let tolerance: CGFloat = 12

                if abs(loc.y - anchor.y) <= tolerance &&
                    loc.x >= 0 &&
                    loc.x <= klineView.bounds.size.width {
                    drawItem.touchMoveIndexList = [index]
                    return true
                }
            }

            if case .globalVerticalLine = drawItem.drawType {
                let anchor = klineView.viewPointFromValuePoint(point)
                let loc = klineView.viewPointFromValuePoint(location)
                let tolerance: CGFloat = 12

                if abs(loc.x - anchor.x) <= tolerance &&
                    loc.y >= 0 &&
                    loc.y <= klineView.bounds.size.height {
                    drawItem.touchMoveIndexList = [index]
                    return true
                }
            }

            if distance(
                p1: klineView.viewPointFromValuePoint(point),
                p2: klineView.viewPointFromValuePoint(location)
            ) <= 10 {
                drawItem.touchMoveIndexList = [index]
                return true
            }
        }
        return false
    }

    static func beganFillTouchMoveItemMapper(_ drawItem: HTDrawItem, _ index: Int, _ location: CGPoint, _ klineView: HTKLineView) -> Bool {
        let point = drawItem.pointList[index]
        
        let lineList = lineListWithIndex(drawItem, index, klineView)
        for (startPoint, endPoint) in lineList {
            let startValuePoint = klineView.viewPointFromValuePoint(startPoint)
            let endValuePoint = klineView.viewPointFromValuePoint(endPoint)
            let valueLocation = klineView.viewPointFromValuePoint(location)
            let distance = pedalPoint(p1: startValuePoint, p2: endValuePoint, x0: valueLocation)
            let minX = min(startValuePoint.x, endValuePoint.x) - 5
            let maxX = max(startValuePoint.x, endValuePoint.x) + 5
            let minY = min(startValuePoint.y, endValuePoint.y) - 5
            let maxY = max(startValuePoint.y, endValuePoint.y) + 5
            if distance <= 10, valueLocation.x > minX, valueLocation.x < maxX, valueLocation.y > minY, valueLocation.y < maxY {
                fillAllTouchMoveItem(drawItem)
                return true
            }
        }
        if index == 2, case .parallelLine = drawItem.drawType {
            let firstPoint = drawItem.pointList[0]
            let secondPoint = drawItem.pointList[1]
            let minX = min(firstPoint.x, secondPoint.x)
            let maxX = max(firstPoint.x, secondPoint.x)
            
            let base = (firstPoint.x - secondPoint.x)
            var k: CGFloat = 1
            if base != 0 {
                k = (firstPoint.y - secondPoint.y) / base
            }
            let b1 = firstPoint.y - firstPoint.x * k
            let b2 = point.y - point.x * k
            let minB = min(b1, b2)
            let maxB = max(b1, b2)
            if location.x > minX, location.x < maxX, location.y > k * location.x + minB, location.y < k * location.x + maxB {
                fillAllTouchMoveItem(drawItem)
                return true
            }
        }
        return false
    }
    
    // 开始 began 拖动时, 找到是否碰到了某个点
    static func beganFillTouchMoveItem(_ drawItemList: [HTDrawItem], _ location: CGPoint, _ klineView: HTKLineView) {
        clearAllTouchMoveIndexList(drawItemList)
        for drawItem in drawItemList.reversed() {
            if (beganFillTouchMoveItemPointMapper(drawItem, location, klineView)) {
                return
            }
        }
        for drawItem in drawItemList.reversed() {
            for (index, _) in drawItem.pointList.enumerated() {
                if (beganFillTouchMoveItemMapper(drawItem, index, location, klineView)) {
                    return
                }
            }
        }
    }
    
    // 是否有正在拖动的点, 如果有的话, 进行更改位移
    static func canResponseTranslation(_ drawItemList: [HTDrawItem], _ translation: CGPoint) -> Bool {
        if let touchMoveItem = findTouchMoveItem(drawItemList) {
            if touchMoveItem.drawIsLock {
                return true
            }
            for touchMoveIndex in touchMoveItem.touchMoveIndexList {
                touchMoveItem.pointList[touchMoveIndex].x += translation.x
                touchMoveItem.pointList[touchMoveIndex].y += translation.y
            }
            return true
        }
        return false
    }
    
    // 清除所有的拖动
    static func clearAllTouchMoveIndexList(_ drawItemList: [HTDrawItem]) -> Void {
        for drawItem in drawItemList {
            drawItem.touchMoveIndexList = []
        }
    }
    
    // 本次是否点中了某个绘图
    static func canResponseLocation(_ drawItemList: [HTDrawItem], _ location: CGPoint, _ klineView: HTKLineView) -> HTDrawItem? {
        beganFillTouchMoveItem(drawItemList, location, klineView)
        let drawItem = findTouchMoveItem(drawItemList)
        clearAllTouchMoveIndexList(drawItemList)
        return drawItem
    }
    
    // 是否会响应这次事件, 如果能响应, 不做绘图, 进行拖动
    static func canResponseTouch(_ drawItemList: [HTDrawItem], _ location: CGPoint, _ translation: CGPoint, _ state: UIGestureRecognizerState, _ klineView: HTKLineView) -> Bool {
        switch state {
        case .began:
            beganFillTouchMoveItem(drawItemList, location, klineView)
            return canResponseTranslation(drawItemList, translation)
        case .changed:
            return canResponseTranslation(drawItemList, translation)
        case .ended:
            let shouldResponseTranslation = canResponseTranslation(drawItemList, translation)
            clearAllTouchMoveIndexList(drawItemList)
            return shouldResponseTranslation
        default:
            return false
        }
    }
    
    
    
}
