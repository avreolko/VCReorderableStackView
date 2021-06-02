//
//  ReorderableStackView.swift
//  VCForm
//
//  Created by Valentin Cherepyanko on 03.03.2020.
//  Copyright © 2020 Valentin Cherepyanko. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

@objc public protocol IReorderableStackViewDelegate: AnyObject {
    @objc optional func dragWillStart(with view: UIView)
    @objc optional func dragDidStart(with view: UIView)
    @objc optional func swapped(index: Int, with: Int)
    @objc optional func dragWillEnd(with view: UIView)
    @objc optional func dragDidEnd(with view: UIView)
}

@objc public protocol IDraggableView: AnyObject {
    @objc optional func dragWillStart()
    @objc optional func dragDidStart()
    @objc optional func dragWillEnd()
    @objc optional func dragDidEnd()
}

public class ReorderableStackView: UIStackView {

    public var reorderingEnabled: Bool = true {
        didSet { self.gestures.forEach { $0.isEnabled = self.reorderingEnabled } }
    }

    private var gestures: [UIGestureRecognizer] = []

    private struct Settings {
        static let pressDuration: Double = 0.2
        static let animationDuration: Double = 0.2
        static let snapshotAlpha: CGFloat = 0.8

        static let otherViewsScale: CGFloat = 0.95
        static let snapshotScale: CGFloat = 1.05
    }

    private var snapshotView: UIView?
    private var originalView: UIView?
    private var originalPosition: CGPoint!
    private var reorderingPoint: CGPoint!

    public weak var delegate: IReorderableStackViewDelegate?

    override public func addArrangedSubview(_ view: UIView) {
        super.addArrangedSubview(view)
        view.isUserInteractionEnabled = true
        self.addGesture(to: view)
    }
    
    open func insertArrangedSubview(_ view: UIView, at stackIndex: Int) {
        super.insertArrangedSubview(view, at: stackIndex)
        view.isUserInteractionEnabled = true
        self.addGesture(to: view)
    }
}

private extension ReorderableStackView {

    func addGesture(to view: UIView) {

        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleGesture(_:)))
        gesture.minimumPressDuration = Settings.pressDuration
        gesture.isEnabled = self.reorderingEnabled

        view.addGestureRecognizer(gesture)
        self.gestures.append(gesture)
    }

    @objc
    func handleGesture(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            self.notifyWillStartDragging(with: gesture)
            self.makeSnapshot(with: gesture)
            self.animateStartDragging()
            self.notifyDidStartDragging(with: gesture)
        case .changed:
            self.moveSnapshot(with: gesture)
            self.reorderViews(with: gesture)
        case .ended, .cancelled, .failed:
            self.notifyWillEndDragging(with: gesture)
            self.swapSnapshotWithOriginal()
            self.animateEndDragging()
            self.notifyDidEndDragging(with: gesture)
        default:
            ()
        }
    }
}

private extension ReorderableStackView {

    func makeSnapshot(with gesture: UILongPressGestureRecognizer) {

        guard let gestureView = gesture.view else { return assertionFailure() }

        let snapshot = gestureView.snapshotView(afterScreenUpdates: true)

        snapshot.map {
            $0.frame = gestureView.frame
            self.addSubview($0)
            self.snapshotView = $0
        }

        self.originalView = gestureView
        self.originalView?.alpha = 0
        self.originalPosition = gesture.location(in: self)
        self.reorderingPoint = gesture.location(in: self)
    }

    func moveSnapshot(with gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)
        let xOffset = location.x - self.originalPosition.x
        let yOffset = location.y - self.originalPosition.y
        let translation = CGAffineTransform(translationX: xOffset, y: yOffset)

        // replicate the scale that was initially applied
        let scale = CGAffineTransform(scaleX: Settings.snapshotScale, y: Settings.snapshotScale)
        self.snapshotView?.transform = scale.concatenating(translation)
    }

    func reorderViews(with gesture: UILongPressGestureRecognizer) {
        
        var snapshotViewMidPoint: CGFloat? = .zero
        var reorderingPoint: CGFloat = .zero
        var reorderViewFrame: CGFloat = .zero
        
        if self.axis == .horizontal {
            snapshotViewMidPoint = self.snapshotView?.frame.midX
            reorderingPoint = self.reorderingPoint.x
        } else {
            snapshotViewMidPoint = self.snapshotView?.frame.midY
            reorderingPoint = self.reorderingPoint.y
        }
        
        guard
            let view = self.originalView,
            let midY = snapshotViewMidPoint,
            let index = self.index(of: view)
        else { return }
        
        let reorderViewIndex = (midY > reorderingPoint)
            ? index + 1
            : index - 1
        
        guard let reorderView = self.view(for: reorderViewIndex) else { return }
        
        var viewMidPoint: CGFloat = .zero
        
        if self.axis == .horizontal {
            reorderViewFrame = reorderView.frame.midX
            viewMidPoint = view.frame.midX
        } else {
            reorderViewFrame = reorderView.frame.midY
            viewMidPoint = view.frame.midY
        }
        
        if midY > max(reorderingPoint, reorderViewFrame)
            || midY < min(reorderingPoint, reorderViewFrame) {
            
            UIView.animate(withDuration: Settings.animationDuration, animations: {
                self.insertArrangedSubview(reorderView, at: index)
                self.insertArrangedSubview(view, at: reorderViewIndex)
            })
            
            reorderingPoint = viewMidPoint
            
            self.delegate?.swapped?(index: index, with: reorderViewIndex)
        }
    }

    func swapSnapshotWithOriginal() {

        guard let view = self.originalView else { return }

        UIView.animate(withDuration: Settings.animationDuration, animations: {
            self.snapshotView?.frame = view.frame
        }, completion: { _ in
            self.snapshotView?.removeFromSuperview()
            self.originalView?.alpha = 1
        })
    }

    func animateStartDragging() {
        UIView.animate(withDuration: Settings.animationDuration) {
            let scale = CGAffineTransform(scaleX: Settings.snapshotScale, y: Settings.snapshotScale)
            self.snapshotView?.transform = scale
            self.snapshotView?.alpha = Settings.snapshotAlpha

            self.scaleOtherViews(to: Settings.otherViewsScale)
        }
    }

    func animateEndDragging() {
        UIView.animate(withDuration: Settings.animationDuration) {
            self.snapshotView?.alpha = 1
            self.scaleOtherViews(to: 1)
        }
    }

    func scaleOtherViews(to scale: CGFloat) {
        for subview in self.arrangedSubviews {
            if subview != self.originalView {
                subview.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }
    }
}

// MARK: - delegate notifications
private extension ReorderableStackView {

    func notifyWillStartDragging(with gesture: UILongPressGestureRecognizer) {
        guard let gestureView = gesture.view else { return assertionFailure() }
        self.delegate?.dragWillStart?(with: gestureView)
        (gestureView as? IDraggableView)?.dragWillStart?()
    }

    func notifyDidStartDragging(with gesture: UILongPressGestureRecognizer) {
        guard let gestureView = gesture.view else { return assertionFailure() }
        self.delegate?.dragDidStart?(with: gestureView)
        (gestureView as? IDraggableView)?.dragDidStart?()
    }

    func notifyWillEndDragging(with gesture: UILongPressGestureRecognizer) {
        guard let gestureView = gesture.view else { return assertionFailure() }
        self.delegate?.dragWillEnd?(with: gestureView)
        (gestureView as? IDraggableView)?.dragWillEnd?()
    }

    func notifyDidEndDragging(with gesture: UILongPressGestureRecognizer) {
        guard let gestureView = gesture.view else { return assertionFailure() }
        self.delegate?.dragDidEnd?(with: gestureView)
        (gestureView as? IDraggableView)?.dragDidEnd?()
    }
}

private extension UIStackView {

    func index(of view: UIView) -> Int? {
        for (index, subview) in self.arrangedSubviews.enumerated() {
            guard view == subview else { continue }
            return index
        }
        return nil
    }

    func view(for index: Int) -> UIView? {
        for (currentIndex, subview) in self.arrangedSubviews.enumerated() {
            guard currentIndex == index else { continue }
            return subview
        }
        return nil
    }
}
