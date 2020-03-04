# VCReorderableStackView

Very simple implementation of drag&drop stack view.
There is a delegate protocol, that sends notification every time, when views swapped.

```swift
public protocol IReorderableStackViewDelegate: AnyObject {
    func swapped(index: Int, with: Int)
}
```

You can Install it through SPM 📦
