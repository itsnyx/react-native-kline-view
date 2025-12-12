//
//  HTKLineContainerView.swift
//  Base64
//
//  Created by hublot on 2020/8/26.
//

import UIKit

class HTKLineContainerView: UIView {
    
    var configManager = HTKLineConfigManager()
    
    @objc var onDrawItemDidTouch: RCTBubblingEventBlock?

    // Fired when the user taps the hover price pill on the right side (long-press selector).
    // JS receives: { price: number }
    @objc var onNewOrder: RCTBubblingEventBlock?
    
    @objc var onDrawItemComplete: RCTBubblingEventBlock?

    // Continuously fired while a drawing (line/text/etc.) is being moved.
    // JS receives the current index, drawType, pointList, and text (if any).
    @objc var onDrawItemMove: RCTBubblingEventBlock?
    
    @objc var onDrawPointComplete: RCTBubblingEventBlock?
    
    // Called when user scrolls to the left edge (request older candles)
    @objc var onEndReached: RCTBubblingEventBlock?
    
    @objc var optionList: String? {
        didSet {
            guard let optionList = optionList else {
                return
            }
            
            RNKLineView.queue.async { [weak self] in
                do {
                    guard let optionListData = optionList.data(using: .utf8),
                          let optionListDict = try JSONSerialization.jsonObject(with: optionListData, options: .allowFragments) as? [String: Any] else {
                        return
                    }
                    self?.configManager.reloadOptionList(optionListDict)
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.reloadConfigManager(self.configManager)
                    }
                } catch {
                    print("Error parsing optionList: \(error)")
                }
            }
        }
    }

    // Lightweight data-only update: replace modelArray without reloading full optionList.
    // Accepts the same modelArray JSON you normally embed inside optionList.
    @objc var modelArray: String? {
        didSet {
            guard let modelArray = modelArray else {
                return
            }
            
            RNKLineView.queue.async { [weak self] in
                do {
                    guard let data = modelArray.data(using: .utf8),
                          let list = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [[String: Any]] else {
                        return
                    }
                    self?.configManager.modelArray = HTKLineModel.packModelArray(list)
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.klineView.reloadContentSize()
                        self.klineView.scrollViewDidScroll(self.klineView)
                    }
                } catch {
                    print("Error parsing modelArray: \(error)")
                }
            }
        }
    }

    lazy var klineView: HTKLineView = {
        let klineView = HTKLineView.init(CGRect.zero, configManager)
        klineView.containerView = self
        return klineView
    }()
    
    lazy var shotView: HTShotView = {
        let shotView = HTShotView.init(frame: CGRect.zero)
        shotView.dimension = 100
        return shotView
    }()

    func setupChildViews() {
        klineView.frame = bounds
        let superShotView = reactSuperview()?.reactSuperview()?.reactSuperview()
        superShotView?.reactSuperview()?.addSubview(shotView)
        shotView.shotView = superShotView
        shotView.reactSetFrame(CGRect.init(x: 50, y: 50, width: shotView.dimension, height: shotView.dimension))
    }

    override var frame: CGRect {
        didSet {
	        setupChildViews()
        }
    }
    
    override func reactSetFrame(_ frame: CGRect) {
        super.reactSetFrame(frame)
        setupChildViews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(klineView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reloadConfigManager(_ configManager: HTKLineConfigManager) {
        
        configManager.onDrawItemDidTouch = { [weak self] (drawItem, drawItemIndex) in
            self?.configManager.shouldReloadDrawItemIndex = drawItemIndex
            guard let drawItem = drawItem, let colorList = drawItem.drawColor.cgColor.components else {
                self?.onDrawItemDidTouch?([
                    "index": drawItemIndex,
                    "shouldReloadDrawItemIndex": drawItemIndex,
                    "id": drawItem?.uid ?? ""
                ])
                return
            }
            self?.onDrawItemDidTouch?([
                "index": drawItemIndex,
                "shouldReloadDrawItemIndex": drawItemIndex,
                "id": drawItem.uid,
                "drawColor": colorList,
                "drawLineHeight": drawItem.drawLineHeight,
                "drawDashWidth": drawItem.drawDashWidth,
                "drawDashSpace": drawItem.drawDashSpace,
                "drawIsLock": drawItem.drawIsLock
            ])
        }
        configManager.onDrawItemComplete = { [weak self] (drawItem, drawItemIndex) in
            guard let this = self, let drawItem = drawItem else {
                self?.onDrawItemComplete?([AnyHashable: Any].init())
                return
            }

            func colorToInt(_ color: UIColor) -> Int {
                var r: CGFloat = 0
                var g: CGFloat = 0
                var b: CGFloat = 0
                var a: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                let ai = Int(a * 255.0) << 24
                let ri = Int(r * 255.0) << 16
                let gi = Int(g * 255.0) << 8
                let bi = Int(b * 255.0)
                return ai | ri | gi | bi
            }

            var pointArray = [[String: Any]]()
            for point in drawItem.pointList {
                pointArray.append([
                    "x": point.x,
                    "y": point.y
                ])
            }
            
            this.onDrawItemComplete?([
                "index": drawItemIndex,
                "id": drawItem.uid,
                "drawType": drawItem.drawType.rawValue,
                "drawColor": colorToInt(drawItem.drawColor),
                "drawLineHeight": drawItem.drawLineHeight,
                "drawDashWidth": drawItem.drawDashWidth,
                "drawDashSpace": drawItem.drawDashSpace,
                "drawIsLock": drawItem.drawIsLock,
                "pointList": pointArray,
                "text": drawItem.text,
                "textColor": colorToInt(drawItem.textColor),
                "textBackgroundColor": colorToInt(drawItem.textBackgroundColor),
                "textCornerRadius": drawItem.textCornerRadius,
                // Expose per-item text font size (falls back to candleTextFontSize when 0 on native).
                "fontSize": drawItem.textFontSize > 0 ? drawItem.textFontSize : configManager.candleTextFontSize,
                // Expose candleMarker position ("top" | "bottom") so JS can persist it.
                "position": drawItem.position
            ])
        }
        configManager.onDrawItemMove = { [weak self] (drawItem, drawItemIndex) in
            guard let drawItem = drawItem else {
                return
            }

            var pointArray = [[String: Any]]()
            for point in drawItem.pointList {
                pointArray.append([
                    "x": point.x,
                    "y": point.y
                ])
            }
            
            self?.onDrawItemMove?([
                "index": drawItemIndex,
                "id": drawItem.uid,
                "drawType": drawItem.drawType.rawValue,
                "pointList": pointArray,
                "text": drawItem.text,
                "position": drawItem.position
            ])
        }
        configManager.onDrawPointComplete = { [weak self] (drawItem, drawItemIndex) in
            guard let drawItem = drawItem else {
                return
            }
            self?.onDrawPointComplete?([
                "pointCount": drawItem.pointList.count
            ])
        }
        
        let reloadIndex = configManager.shouldReloadDrawItemIndex
        if reloadIndex >= 0, reloadIndex < klineView.drawContext.drawItemList.count {
            let drawItem = klineView.drawContext.drawItemList[reloadIndex]
            drawItem.drawColor = configManager.drawColor
            drawItem.drawLineHeight = configManager.drawLineHeight
            drawItem.drawDashWidth = configManager.drawDashWidth
            drawItem.drawDashSpace = configManager.drawDashSpace
            drawItem.drawIsLock = configManager.drawIsLock
            if (configManager.drawShouldTrash) {
                configManager.shouldReloadDrawItemIndex = HTDrawState.showPencil.rawValue
                klineView.drawContext.drawItemList.remove(at: reloadIndex)
                configManager.drawShouldTrash = false
            }
            klineView.drawContext.setNeedsDisplay()
        }

        // If a serialized drawing list was provided from React Native,
        // rebuild the native drawItemList from it (pre-insert drawings).
        if let rawList = configManager.drawItemList {
            klineView.drawContext.clearDrawItemList()
            for item in rawList {
                guard let points = item["pointList"] as? [[String: Any]],
                      points.count > 0,
                      let firstPoint = points.first
                else {
                    continue
                }

                let rawType = (item["drawType"] as? Int) ?? 0
                guard let drawType = HTDrawType(rawValue: rawType) else {
                    continue
                }
                
                guard let x = firstPoint["x"] as? CGFloat else {
                    continue
                }
                
                // Optional position for candleMarker ("top" | "bottom").
                let position = (item["position"] as? String) ?? "bottom"
                
                // For candleMarker, derive Y from the candle body at this timestamp so
                // JS can omit `y` in pointList and only provide the horizontal anchor.
                let startY: CGFloat
                if drawType == .candleMarker {
                    let isTop = position.lowercased() == "top"
                    startY = candleMarkerBodyValue(forX: x, useTop: isTop)
                } else {
                    guard let y = firstPoint["y"] as? CGFloat else {
                        continue
                    }
                    startY = y
                }
                
                let uid = item["id"] as? String
                let drawItem = HTDrawItem(drawType, CGPoint(x: x, y: startY), uid: uid)
                drawItem.position = position

                // Remaining points
                if points.count > 1 {
                    for pointDict in points.dropFirst() {
                        guard let px = pointDict["x"] as? CGFloat,
                              let py = pointDict["y"] as? CGFloat
                        else {
                            continue
                        }
                        drawItem.pointList.append(CGPoint(x: px, y: py))
                    }
                }

                // Style properties, with fallback to global draw config
                if let colorInt = item["drawColor"] as? Int,
                   let uiColor = RCTConvert.uiColor(colorInt) {
                    drawItem.drawColor = uiColor
                } else {
                    drawItem.drawColor = configManager.drawColor
                }
                if let lineHeight = item["drawLineHeight"] as? CGFloat {
                    drawItem.drawLineHeight = lineHeight
                } else {
                    drawItem.drawLineHeight = configManager.drawLineHeight
                }
                if let dashWidth = item["drawDashWidth"] as? CGFloat {
                    drawItem.drawDashWidth = dashWidth
                } else {
                    drawItem.drawDashWidth = configManager.drawDashWidth
                }
                if let dashSpace = item["drawDashSpace"] as? CGFloat {
                    drawItem.drawDashSpace = dashSpace
                } else {
                    drawItem.drawDashSpace = configManager.drawDashSpace
                }
                if let isLock = item["drawIsLock"] as? Bool {
                    drawItem.drawIsLock = isLock
                } else {
                    drawItem.drawIsLock = configManager.drawIsLock
                }

                if let text = item["text"] as? String {
                    drawItem.text = text
                }

                if let textColorInt = item["textColor"] as? Int,
                   let textColor = RCTConvert.uiColor(textColorInt) {
                    drawItem.textColor = textColor
                } else {
                    drawItem.textColor = configManager.drawTextColor
                }
                if let textBackgroundColorInt = item["textBackgroundColor"] as? Int,
                   let textBackgroundColor = RCTConvert.uiColor(textBackgroundColorInt) {
                    drawItem.textBackgroundColor = textBackgroundColor
                } else {
                    drawItem.textBackgroundColor = configManager.drawTextBackgroundColor
                }
                if let textCornerRadius = item["textCornerRadius"] as? CGFloat {
                    drawItem.textCornerRadius = textCornerRadius
                } else {
                    drawItem.textCornerRadius = configManager.drawTextCornerRadius
                }
                // Optional per-item font size for text annotations
                if let fontSize = item["fontSize"] as? CGFloat {
                    drawItem.textFontSize = fontSize
                } else {
                    drawItem.textFontSize = configManager.candleTextFontSize
                }

                klineView.drawContext.drawItemList.append(drawItem)
            }
            klineView.drawContext.setNeedsDisplay()
        }

        klineView.reloadConfigManager(configManager)
        shotView.shotColor = configManager.shotBackgroundColor
        if configManager.shouldFixDraw {
            configManager.shouldFixDraw = false
            klineView.drawContext.fixDrawItemList()
        }
        if (configManager.shouldClearDraw) {
            configManager.drawType = .none
            configManager.shouldClearDraw = false
            klineView.drawContext.clearDrawItemList()
        }
    }
    
    private func convertLocation(_ location: CGPoint) -> CGPoint {
        var reloadLocation = location
        reloadLocation.x = max(min(reloadLocation.x, bounds.size.width), 0)
        reloadLocation.y = max(min(reloadLocation.y, bounds.size.height), 0)
//        reloadLocation.x += klineView.contentOffset.x
        reloadLocation = klineView.valuePointFromViewPoint(reloadLocation)
        return reloadLocation
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        guard view == klineView else {
            return view
        }

        // When no drawing UI is active, let HTKLineView handle touches so the chart scrolls normally.
        if configManager.shouldReloadDrawItemIndex == HTDrawState.none.rawValue {
            return view
        }

        // If we are actively creating a drawing (line / rect / etc.), always route touches to
        // the container so drawing gestures don't cause the chart itself to scroll.
        if configManager.drawType != .none {
            return self
        }

        // In "show" / manage-drawings mode (JS may pass drawType = -1 which maps to `.none` here),
        // we only intercept touches that actually hit an existing drawing. All other touches go to
        // HTKLineView so the user can still scroll the chart.
        if HTDrawItem.canResponseLocation(
            klineView.drawContext.drawItemList,
            convertLocation(point),
            klineView
        ) != nil {
            return self
        } else {
            return klineView
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesGesture(touches, .began)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesGesture(touches, .changed)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesGesture(touches, .ended)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    func touchesGesture(_ touched: Set<UITouch>, _ state: UIGestureRecognizerState) {
        guard var location = touched.first?.location(in: self) else {
            shotView.shotPoint = nil
            return
        }
        var previousLocation = touched.first?.previousLocation(in: self) ?? location
        location = convertLocation(location)
        previousLocation = convertLocation(previousLocation)
        
        let translation = CGPoint.init(x: location.x - previousLocation.x, y: location.y - previousLocation.y)
        
        klineView.drawContext.touchesGesture(location, translation, state)
        shotView.shotPoint = state != .ended ? touched.first?.location(in: self) : nil
    }

    /// For a given X-value (timestamp), find the candle whose id is closest and
    /// return either the bottom or top of its real body in value-space
    /// (min(open, close) when useTop is false; max(open, close) when true).
    /// This mirrors HTDrawContext.bodyBottomValue(forX:)/bodyTopValue(forX:) and is used
    /// when reconstructing candleMarker drawings from JS that only provide `x`.
    private func candleMarkerBodyValue(forX value: CGFloat, useTop: Bool) -> CGFloat {
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
        let bodyLow = closest.low
        let bodyHigh = closest.high
        return useTop ? bodyHigh : bodyLow
    }

}

