//
//  ReorderableStackView.swift
//  VCForm
//
//  Created by Valentin Cherepyanko on 03.03.2020.
//  Copyright © 2020 Valentin Cherepyanko. All rights reserved.
//

import UIKit

public protocol IReorderableStackViewDelegate: AnyObject {
    func swapped(index: Int, with: Int)
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
            self.makeSnapshot(with: gesture)
            self.animateStartDragging()
        case .changed:
            self.moveSnapshot(with: gesture)
            self.reorderViews(with: gesture)
        case .ended, .cancelled, .failed:
            self.swapSnapshotWithOriginal()
            self.animateEndDragging()
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

        guard
            let view = self.originalView,
            let midY = self.snapshotView?.frame.midY,
            let index = self.index(of: view)
        else { return }

        let reorderViewIndex = (midY > self.reorderingPoint.y)
            ? index + 1
            : index - 1

        guard let reorderView = self.view(for: reorderViewIndex) else { return }

        if midY > max(self.reorderingPoint.y, reorderView.frame.midY)
        || midY < min(self.reorderingPoint.y, reorderView.frame.midY) {

            UIView.animate(withDuration: Settings.animationDuration, animations: {
                self.insertArrangedSubview(reorderView, at: index)
                self.insertArrangedSubview(view, at: reorderViewIndex)
            })

            self.reorderingPoint.y = view.frame.midY

            self.delegate?.swapped(index: index, with: reorderViewIndex)
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
