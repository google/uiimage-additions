[![Apache
License](https://img.shields.io/github/license/google/uiimage-additions.svg)](LICENSE)
[![Travis](https://img.shields.io/travis/google/uiimage-additions.svg)](https://travis-ci.org/google/uiimage-additions)

# UIImage Additions

A collection of miscellaneous utility methods for `UIImage` for memory-efficient
image transformations.

## Setup

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'UIImage+FBLAdditions', '~> 1.0'
```

Or, if you would also like to include the tests:

```ruby
pod 'UIImage+FBLAdditions', '~> 1.0', :testspecs => ['Tests']
```

Then, run `pod install`.

### Carthage

Add the following to your `Cartfile`:

```
github "google/uiimage-additions"
```

Then, run `carthage update` and follow the [rest of instructions](https://github.com/Carthage/Carthage#getting-started).

### Import

Import the umbrella header as:

```objectivec
#import <UIImage_FBLAdditions/UIImage+FBLAdditions.h>
```

Or:

```objectivec
#import "UIImage+FBLAdditions.h"
```

Or, the module:

```objectivec
@import UIImage_FBLAdditions;
```
