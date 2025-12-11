//
//  HTDrawView.swift
//  Base64
//
//  Created by hublot on 2020/8/26.
//

import UIKit

class HTDrawContext {
    
    var configManager: HTKLineConfigManager
    
    weak var klineView: HTKLineView?
    

    lazy var drawItemList: [HTDrawItem] = {
        let drawItemList = [HTDrawItem]()
        return drawItemList
    }()
    
    init(_ klineView: HTKLineView, _ configManager: HTKLineConfigManager) {
        self.klineView = klineView
        self.configManager = configManager
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var breakTouch = false
    // Tracks whether the user is currently moving an existing drawing item.
    private var isMovingExistingItem = false
    
    func touchesGesture(_ location: CGPoint, _ translation: CGPoint, _ state: UIGestureRecognizerState) {
        guard let klineView = klineView, breakTouch == false else {
            if state == .ended {
                breakTouch = false
            }
            return
        }

        // If we were moving an existing item and the gesture just ended, fire a single move callback.
        if state == .ended, isMovingExistingItem,
           let moveItem = HTDrawItem.findTouchMoveItem(drawItemList),
           let moveItemIndex = drawItemList.index(of: moveItem) {
            configManager.onDrawItemMove?(moveItem, moveItemIndex)
            isMovingExistingItem = false
            setNeedsDisplay()
            return
        }
        switch state {
        case .began:
            if (configManager.shouldReloadDrawItemIndex > HTDrawState.showContext.rawValue) {
                let selectedDrawItem = drawItemList[configManager.shouldReloadDrawItemIndex]
                if (selectedDrawItem.pointList.count >= selectedDrawItem.drawType.count) {
                    if (HTDrawItem.canResponseLocation(drawItemList, location, klineView) != selectedDrawItem) {
                        configManager.onDrawItemDidTouch?(nil, HTDrawState.showPencil.rawValue)
                        breakTouch = true
                        setNeedsDisplay()
                        return
                    }
                }
//            } else if (configManager.shouldReloadDrawItemIndex > HTDrawState.showPencil.rawValue) {
//                let selectedDrawItem = HTDrawItem.canResponseLocation(drawItemList, location, translation, state, klineView)
//                if let selectedDrawItem = selectedDrawItem, let selectedDrawItemIndex = drawItemList.index(of: selectedDrawItem) {
//                    configManager.onDrawItemDidTouch?(selectedDrawItem, selectedDrawItemIndex)
//                    setNeedsDisplay()
//                    return
//                } else {
//                    if HTDrawItem.canResponseTouch(drawItemList, location, translation, state, klineView) {
//                        setNeedsDisplay()
//                        return
//                    }
//                }
            }
        case .changed:
            break
        case .ended:
            break
        default:
            break
        }
        if HTDrawItem.canResponseTouch(drawItemList, location, translation, state, klineView) {
            if state == .began,
               let moveItem = HTDrawItem.findTouchMoveItem(drawItemList),
               let moveItemIndex = drawItemList.index(of: moveItem) {
                // User started interacting with an existing drawing.
                isMovingExistingItem = true
                configManager.onDrawItemDidTouch?(moveItem, moveItemIndex)
            }
            setNeedsDisplay()
            return
        }
        if (configManager.drawType == .none) {
            return
        }
        
//        let moveDrawItem = HTDrawItem.findTouchMoveItem(drawItemList)
//        let canResponse = false
//        if (configManager.shouldReloadDrawItemIndex == HTDrawState.showPencil.rawValue && state == .ended && translation == CGPoint.zero) {
//            if moveDrawItem != nil {
//                configManager.shouldReloadDrawItemIndex = HTDrawState
//            }
//        }
//
//
//        // 能够处理点击, 改变拖动的点, 重新绘制
//        if let klineView = klineView, ) {
//            // 如果移动了或者点击了, 去弹起配置弹窗
//            if let moveDrawItem = moveDrawItem, let moveDrawItemIndex = drawItemList.firstIndex(of: moveDrawItem), state != .changed {
//                configManager.onDrawItemDidTouch?(moveDrawItem, moveDrawItemIndex)
//            }
//            setNeedsDisplay()
//            return
//        }
    
        
        let drawItem = drawItemList.last
        switch state {
        case .began:
            if (drawItem == nil || (drawItem?.pointList.count ?? 0) >= (drawItem?.drawType.count ?? 0)) {
                var startLocation = location
                // For candleMarker, ignore the tapped Y-value and snap to the
                // bottom of the corresponding candle body (min(open, close)).
                if configManager.drawType == .candleMarker {
                    startLocation = CGPoint(
                        x: location.x,
                        y: bodyBottomValue(forX: location.x)
                    )
                }
                let drawItem = HTDrawItem.init(configManager.drawType, startLocation)
                drawItem.drawColor = configManager.drawColor
                drawItem.drawLineHeight = configManager.drawLineHeight
                drawItem.drawDashWidth = configManager.drawDashWidth
                drawItem.drawDashSpace = configManager.drawDashSpace
                drawItem.textColor = configManager.drawTextColor
                drawItem.textBackgroundColor = configManager.drawTextBackgroundColor
                drawItem.textCornerRadius = configManager.drawTextCornerRadius
                // Initialize per-item text font size from the current global candle text size,
                // but make it a bit larger by default (2x).
                drawItem.textFontSize = configManager.candleTextFontSize * 2
                
                drawItemList.append(drawItem)
                configManager.onDrawItemDidTouch?(drawItem, drawItemList.count - 1)
            } else {
                drawItem?.pointList.append(location)
            }
        case .ended, .changed:
            let length = drawItem?.pointList.count ?? 0
            if length >= 1 {
                let index = length - 1
                drawItem?.pointList[index] = location
                // 最后一个点起笔
                if case .ended = state, let drawItem = drawItem {
                    // When finishing a drag while creating/editing a drawing, report the final position once.
                    configManager.onDrawItemMove?(drawItem, drawItemList.count - 1)
                    configManager.onDrawPointComplete?(drawItem, drawItemList.count - 1)
                    if index == drawItem.drawType.count - 1 {
                        configManager.onDrawItemComplete?(drawItem, drawItemList.count - 1)
                        if configManager.drawShouldContinue {
                            configManager.shouldReloadDrawItemIndex = HTDrawState.showContext.rawValue
                        } else {
                            configManager.drawType = .none
                        }
                    }
                }
            }
        default:
            break
        }
        setNeedsDisplay()
    }
    
    func fixDrawItemList() {
        guard let drawItem = drawItemList.last else {
            return
        }
        if drawItem.pointList.count < drawItem.drawType.count {
            drawItemList.removeLast()
        }
        setNeedsDisplay()
    }
    
    func clearDrawItemList() {
        drawItemList = []
        setNeedsDisplay()
    }
    
    func drawLine(_ context: CGContext, _ drawItem: HTDrawItem, _ startPoint: CGPoint, _ endPoint: CGPoint) {
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.setStrokeColor(drawItem.drawColor.cgColor)
        context.setLineWidth(drawItem.drawLineHeight)
        var dashList = [drawItem.drawDashWidth, drawItem.drawDashSpace]
        if drawItem.drawDashSpace == 0 {
            dashList = []
        }
        context.setLineDash(phase: 0, lengths: dashList)
        context.drawPath(using: .stroke)
    }

    /// For a given X-value (timestamp), find the candle whose id is closest and
    /// return the bottom of its real body (min(open, close)) in value-space.
    /// This is used to anchor candleMarker pointers to the corresponding candle.
    private func bodyBottomValue(forX value: CGFloat) -> CGFloat {
        guard !configManager.modelArray.isEmpty else {
            return value
        }
        var closest = configManager.modelArray[0]
        var minDiff = abs(closest.id - value)
        for model in configManager.modelArray {
            let diff = abs(model.id - value)
            if diff < minDiff {
                minDiff = diff
                closest = model
            }
        }
        return min(closest.open, closest.close)
    }
    
    func setNeedsDisplay() {
        klineView?.setNeedsDisplay()
    }

    func drawMapper(_ context: CGContext, _ drawItem: HTDrawItem, _ index: Int, _ itemIndex: Int) {
        guard let klineView = klineView else {
            return
        }
        let point = drawItem.pointList[index]

        // Candle marker: bubble with text and a pointer to a specific candle/price.
        if drawItem.drawType == .candleMarker {
            let viewPoint = klineView.viewPointFromValuePoint(point)

            let fontSize = drawItem.textFontSize > 0
                ? drawItem.textFontSize
                : configManager.candleTextFontSize
            let font = configManager.createFont(fontSize)
            let text = drawItem.text as NSString

            let paddingH: CGFloat = 12
            let paddingV: CGFloat = 6
            let gap: CGFloat = 4
            let triangleHeight: CGFloat = 6
            let triangleHalfWidth: CGFloat = 6
            let marginX: CGFloat = 4

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: drawItem.textColor
            ]
            let textSize = text.size(withAttributes: attributes)
            let bubbleWidth = textSize.width + paddingH * 2
            let bubbleHeight = textSize.height + paddingV * 2

            var centerX = viewPoint.x
            var left = centerX - bubbleWidth / 2
            var right = centerX + bubbleWidth / 2

            // Clamp bubble within bounds and adjust center if needed.
            if left < marginX {
                let shift = marginX - left
                left += shift
                right += shift
                centerX += shift
            }
            let maxRight = klineView.bounds.size.width - marginX
            if right > maxRight {
                let shift = right - maxRight
                left -= shift
                right -= shift
                centerX -= shift
            }

            let triangleBaseY = viewPoint.y + gap
            let rect = CGRect(
                x: left,
                y: triangleBaseY + triangleHeight,
                width: bubbleWidth,
                height: bubbleHeight
            )

            context.saveGState()

            // Bubble background
            context.setFillColor(drawItem.textBackgroundColor.cgColor)
            let radius = drawItem.textCornerRadius
            let bubblePath = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            context.addPath(bubblePath.cgPath)
            context.drawPath(using: .fill)

            // Pointer triangle from bubble to candle/price
            let trianglePath = UIBezierPath()
            trianglePath.move(to: viewPoint)
            trianglePath.addLine(to: CGPoint(x: centerX - triangleHalfWidth, y: triangleBaseY))
            trianglePath.addLine(to: CGPoint(x: centerX + triangleHalfWidth, y: triangleBaseY))
            trianglePath.close()
            context.setFillColor(drawItem.textBackgroundColor.cgColor)
            context.addPath(trianglePath.cgPath)
            context.drawPath(using: .fill)

            // Text inside bubble
            let textPoint = CGPoint(
                x: rect.minX + paddingH,
                y: rect.minY + paddingV
            )
            text.draw(at: textPoint, withAttributes: attributes)

            context.restoreGState()

            if itemIndex == configManager.shouldReloadDrawItemIndex {
                context.addArc(center: viewPoint, radius: 10, startAngle: 0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
                context.setFillColor(drawItem.drawColor.withAlphaComponent(0.5).cgColor)
                context.drawPath(using: .fill)
                context.addArc(center: viewPoint, radius: 4, startAngle: 0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
                context.setFillColor(drawItem.drawColor.cgColor)
                context.drawPath(using: .fill)
            }
            return
        }

        // Global price-level horizontal line: spans full chart width at a given price.
        if drawItem.drawType == .globalHorizontalLine ||
            drawItem.drawType == .globalHorizontalLineWithLabel {
            let viewPoint = klineView.viewPointFromValuePoint(point)
            let start = CGPoint(x: 0, y: viewPoint.y)
            let end = CGPoint(x: klineView.bounds.size.width, y: viewPoint.y)

            context.saveGState()
            context.setStrokeColor(drawItem.drawColor.cgColor)
            context.setLineWidth(drawItem.drawLineHeight)
            var dashList = [drawItem.drawDashWidth, drawItem.drawDashSpace]
            if drawItem.drawDashSpace == 0 {
                dashList = []
            }
            context.setLineDash(phase: 0, lengths: dashList)
            context.move(to: start)
            context.addLine(to: end)
            context.drawPath(using: .stroke)
            context.restoreGState()

            // Labels: optional custom text on the left and price on the right.
            let priceValue = point.y
            let priceText = configManager.precision(priceValue, configManager.price)
            let leftText = (drawItem.text.isEmpty ? nil : drawItem.text)

            let font = configManager.createFont(configManager.candleTextFontSize)

            let priceAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: configManager.candleTextColor
            ]
            let leftAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: (drawItem.textColor)
            ]

            let priceSize = (priceText as NSString).size(withAttributes: priceAttributes)
            let paddingH: CGFloat = 8
            let paddingV: CGFloat = 4
            let marginX: CGFloat = 4

            // Baseline above the line so the labels do not overlap the stroke.
            let textHeight = priceSize.height
            var baseLineY = viewPoint.y - textHeight - paddingV
            if baseLineY < textHeight {
                baseLineY = textHeight
            }

            // Left label (custom text), only for globalHorizontalLineWithLabel.
            if drawItem.drawType == .globalHorizontalLineWithLabel, let label = leftText {
                let leftSize = (label as NSString).size(withAttributes: leftAttributes)
                let left = marginX
                let top = baseLineY - leftSize.height - paddingV
                let rect = CGRect(
                    x: left,
                    y: top,
                    width: leftSize.width + paddingH * 2,
                    height: leftSize.height + paddingV * 2
                )

                context.setFillColor(configManager.panelBackgroundColor.cgColor)
                let radius = rect.height / 2
                let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
                context.addPath(path.cgPath)
                context.drawPath(using: .fill)

                // Border – use line color
                context.setStrokeColor(drawItem.drawColor.cgColor)
                context.addPath(path.cgPath)
                context.drawPath(using: .stroke)

                let textPoint = CGPoint(x: rect.minX + paddingH, y: rect.minY + paddingV)
                (label as NSString).draw(at: textPoint, withAttributes: leftAttributes)
            }

            // Right price label.
            let rightRectWidth = priceSize.width + paddingH * 2
            let rightRectRight = klineView.bounds.size.width - marginX
            let rightRectLeft = rightRectRight - rightRectWidth
            let rightTop = baseLineY - priceSize.height - paddingV
            let priceRect = CGRect(
                x: rightRectLeft,
                y: rightTop,
                width: rightRectWidth,
                height: priceSize.height + paddingV * 2
            )

            context.setFillColor(configManager.panelBackgroundColor.cgColor)
            let priceRadius = priceRect.height / 2
            let pricePath = UIBezierPath(roundedRect: priceRect, cornerRadius: priceRadius)
            context.addPath(pricePath.cgPath)
            context.drawPath(using: .fill)

            context.setStrokeColor(configManager.panelBorderColor.cgColor)
            context.addPath(pricePath.cgPath)
            context.drawPath(using: .stroke)

            let priceTextPoint = CGPoint(
                x: priceRect.minX + paddingH,
                y: priceRect.minY + paddingV
            )
            (priceText as NSString).draw(at: priceTextPoint, withAttributes: priceAttributes)

            if itemIndex == configManager.shouldReloadDrawItemIndex {
                context.addArc(center: viewPoint, radius: 10, startAngle: 0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
                context.setFillColor(drawItem.drawColor.withAlphaComponent(0.5).cgColor)
                context.drawPath(using: .fill)
                context.addArc(center: viewPoint, radius: 4, startAngle: 0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
                context.setFillColor(drawItem.drawColor.cgColor)
                context.drawPath(using: .fill)
            }
            return
        }

        // Global time-level vertical line: spans full chart height at a given timestamp.
        if case .globalVerticalLine = drawItem.drawType {
            let viewPoint = klineView.viewPointFromValuePoint(point)
            let start = CGPoint(x: viewPoint.x, y: 0)
            let end = CGPoint(x: viewPoint.x, y: klineView.bounds.size.height)

            context.saveGState()
            context.setStrokeColor(drawItem.drawColor.cgColor)
            context.setLineWidth(drawItem.drawLineHeight)
            var dashList = [drawItem.drawDashWidth, drawItem.drawDashSpace]
            if drawItem.drawDashSpace == 0 {
                dashList = []
            }
            context.setLineDash(phase: 0, lengths: dashList)
            context.move(to: start)
            context.addLine(to: end)
            context.drawPath(using: .stroke)
            context.restoreGState()

            if itemIndex == configManager.shouldReloadDrawItemIndex {
                context.addArc(center: viewPoint, radius: 10, startAngle: 0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
                context.setFillColor(drawItem.drawColor.withAlphaComponent(0.5).cgColor)
                context.drawPath(using: .fill)
                context.addArc(center: viewPoint, radius: 4, startAngle: 0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
                context.setFillColor(drawItem.drawColor.cgColor)
                context.drawPath(using: .fill)
            }
            return
        }

        // Special handling for text annotations: draw text at the anchor point with background.
        if case .text = drawItem.drawType {
            let viewPoint = klineView.viewPointFromValuePoint(point)
            // Use per-item font size when provided; otherwise fall back to the global candleTextFontSize.
            let fontSize = drawItem.textFontSize > 0 ? drawItem.textFontSize : configManager.candleTextFontSize
            let font = configManager.createFont(fontSize)
            let text = drawItem.text as NSString
            if !drawItem.text.isEmpty {
                let paddingH: CGFloat = 12
                let paddingV: CGFloat = 6
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: drawItem.textColor
                ]
                let textSize = text.size(withAttributes: attributes)
                let rect = CGRect(
                    x: viewPoint.x,
                    y: viewPoint.y,
                    width: textSize.width + paddingH * 2,
                    height: textSize.height + paddingV * 2
                )

                context.setFillColor(drawItem.textBackgroundColor.cgColor)
                let radius = drawItem.textCornerRadius
                let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
                context.addPath(path.cgPath)
                context.drawPath(using: .fill)

                let textPoint = CGPoint(x: viewPoint.x + paddingH, y: viewPoint.y + paddingV)
                text.draw(at: textPoint, withAttributes: attributes)
            }

            if itemIndex == configManager.shouldReloadDrawItemIndex {
                context.addArc(center: viewPoint, radius: 10, startAngle: 0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
                context.setFillColor(drawItem.drawColor.withAlphaComponent(0.5).cgColor)
                context.drawPath(using: .fill)
                context.addArc(center: viewPoint, radius: 4, startAngle: 0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
                context.setFillColor(drawItem.drawColor.cgColor)
                context.drawPath(using: .fill)
            }
            return
        }
        let lineList = HTDrawItem.lineListWithIndex(drawItem, index, klineView)
        if index == 2, case .parallelLine = drawItem.drawType, let (startPoint, endPoint) = lineList.first {
            let firstPoint = drawItem.pointList[0]
            let secondPoint = drawItem.pointList[1]
            context.move(to: klineView.viewPointFromValuePoint(firstPoint))
            context.addLine(to: klineView.viewPointFromValuePoint(secondPoint))
            context.addLine(to: klineView.viewPointFromValuePoint(startPoint))
            context.addLine(to: klineView.viewPointFromValuePoint(endPoint))
            context.closePath()
            context.setFillColor(drawItem.drawColor.withAlphaComponent(0.5).cgColor)
            context.drawPath(using: .fill)
            let dashStartPoint = HTDrawItem.centerPoint(p1: firstPoint, p2: endPoint)
            let dashEndPoint = HTDrawItem.centerPoint(p1: secondPoint, p2: startPoint)
            context.move(to: klineView.viewPointFromValuePoint(dashStartPoint))
            context.addLine(to: klineView.viewPointFromValuePoint(dashEndPoint))
            context.setLineDash(phase: 0, lengths: [4, 4])
            context.setStrokeColor(drawItem.drawColor.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1)
            context.drawPath(using: .stroke)
        }
        for (startPoint, endPoint) in lineList {
            drawLine(context, drawItem, klineView.viewPointFromValuePoint(startPoint), klineView.viewPointFromValuePoint(endPoint))
        }

        if (itemIndex != configManager.shouldReloadDrawItemIndex) {
            return
        }
        
        context.addArc(center: klineView.viewPointFromValuePoint(point), radius: 10, startAngle: 0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
        context.setFillColor(drawItem.drawColor.withAlphaComponent(0.5).cgColor)
        context.drawPath(using: .fill)
        context.addArc(center: klineView.viewPointFromValuePoint(point), radius: 4, startAngle: 0, endAngle: CGFloat(Double.pi * 2.0), clockwise: true)
        context.setFillColor(drawItem.drawColor.cgColor)
        context.drawPath(using: .fill)
    }
    
    func draw(_ contenOffset: CGFloat) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        for (itemIndex, drawItem) in drawItemList.enumerated() {
            for (index, _) in drawItem.pointList.enumerated() {
                drawMapper(context, drawItem, index, itemIndex)
            }
        }
    }

}
