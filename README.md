# VCReorderableStackView
A simple implementation of the drag-and-drop stack view

## Demo
![reorderable_demo](https://user-images.githubusercontent.com/5366222/77224811-d1ab7880-6b9b-11ea-8c24-73a9476e7f10.gif)

## Installation
Install with SPM 📦

## Usage
The `IReorderableStackViewDelegate` protocol fires a callback whenever views are swapped

```swift
public protocol IReorderableStackViewDelegate: AnyObject {
    func swapped(index: Int, with: Int)
}
```


