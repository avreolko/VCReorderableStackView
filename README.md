# VCReorderableStackView
Very simple implementation of drag&drop stack view

## Demo
![reorderable_demo](https://user-images.githubusercontent.com/5366222/77224811-d1ab7880-6b9b-11ea-8c24-73a9476e7f10.gif)

## Getting started
There is a delegate protocol, that sends notification every time, when views swapped

```swift
public protocol IReorderableStackViewDelegate: AnyObject {
    func swapped(index: Int, with: Int)
}
```

## Installation
📦 SPM
