import SwiftUI

// zip: SwiftUI-র `.toolbar(content:)`-এর দুইটা overload আছে — একটা `View`-এর
// জন্য, একটা `ToolbarContent`-এর জন্য। ভেতরে যদি ঠিক একটামাত্র `ToolbarItem`
// থাকে, তাহলে কিছু Xcode/SDK কম্বিনেশনে (Xcode 16.4 / iOS 18.5 SDK) compiler
// দুইটার মধ্যে choose করতে না পেরে "ambiguous use of 'toolbar(content:)'"
// error দেয়। এই হেল্পার ফাংশনটার রিটার্ন টাইপ স্পষ্টভাবে `some ToolbarContent`
// বলে দেওয়ায় সেই ambiguity আর হয় না — পুরো অ্যাপে বারবার ব্যবহৃত
// single cancel/close-button toolbar-এর জন্য একটাই জায়গা থেকে এটা fix করা হলো।
@ToolbarContentBuilder
func cancelToolbarItem(_ title: String, action: @escaping () -> Void) -> some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
        Button(title, action: action)
    }
}

// একই কারণে সাধারণ (Button/Menu-সহ যেকোনো) single-item `.toolbar { ToolbarItem(...) { ... } }`
// ব্লকের জন্যও একই সমস্যা হয় — এই জেনেরিক wrapper সেগুলোর জন্য।
@ToolbarContentBuilder
func toolbarItem<Content: View>(
    placement: ToolbarItemPlacement,
    @ViewBuilder content: @escaping () -> Content
) -> some ToolbarContent {
    ToolbarItem(placement: placement, content: content)
}

// `.toolbar { ToolbarItemGroup(...) { ... } }`-এর একই সমস্যার জন্য।
@ToolbarContentBuilder
func toolbarItemGroup<Content: View>(
    placement: ToolbarItemPlacement,
    @ViewBuilder content: @escaping () -> Content
) -> some ToolbarContent {
    ToolbarItemGroup(placement: placement, content: content)
}
