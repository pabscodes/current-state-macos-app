# Apple Liquid Glass -- Comprehensive Reference for SwiftUI macOS Development

> Announced June 9, 2025 at WWDC. Ships with iOS 26, iPadOS 26, macOS 26 (Tahoe), watchOS 26, tvOS 26, visionOS 26.

---

## Table of Contents

1. [Core Design Principles](#1-core-design-principles)
2. [Visual Characteristics](#2-visual-characteristics)
3. [SwiftUI APIs](#3-swiftui-apis)
4. [macOS-Specific Guidance](#4-macos-specific-guidance)
5. [Color, Typography, and Icons](#5-color-typography-and-icons)
6. [Code Examples](#6-code-examples)
7. [Best Practices](#7-best-practices)
8. [WWDC Sessions and Resources](#8-wwdc-sessions-and-resources)

---

## 1. Core Design Principles

### What Is Liquid Glass?

Liquid Glass is a **digital meta-material** -- not a recreation of physical glass, but a new material that combines the optical properties of glass (translucency, reflection, refraction) with the fluidity of liquid. It is the most extensive software design update Apple has made since iOS 7, reshaping the relationship between interface and content.

Liquid Glass is a **translucent, dynamic material** whose color is informed by surrounding content and intelligently adapts between light and dark environments. It uses real-time rendering and dynamically reacts to movement with specular highlights.

### The Three Pillars

Apple distills the Liquid Glass design system into three foundational principles:

**Hierarchy** -- Content at the center. Establish a clear visual hierarchy where controls and interface elements elevate and distinguish the content beneath them. UI components dynamically prioritize, hide, or simplify based on user actions and content. Tab bars and navigation adapt in real-time rather than remaining static.

**Harmony** -- Alignment between hardware and software. Glass effects blend the interface seamlessly into apps and devices. Shapes follow hardware form factors. The concentric design of the hardware and software creates harmony between interface elements.

**Consistency** -- Adaptive design across contexts. Consistency stretches across contexts without forcing uniformity. Elements adapt fluidly across devices while maintaining predictable patterns. The design extends across all Apple platforms for the first time, establishing harmony while maintaining each platform's distinct qualities.

### Philosophy

- **Content is primary.** Liquid Glass exists to serve content, not to decorate.
- **Navigation layer only.** Liquid Glass is exclusively for the navigation layer floating above content -- never apply it to content itself (lists, tables, media).
- **Material behavior.** Treat Liquid Glass like a physical material -- consider light sources, layering, and how surfaces interact.
- **Motion as a cue.** Subtle animations (lensing, refraction) communicate state changes and affordances without overwhelming the user.

---

## 2. Visual Characteristics

### Lensing

The primary way Liquid Glass defines itself visually. It dynamically bends and concentrates light, creating a transparent, lightweight appearance while providing definition against background content. When Liquid Glass flexes and morphs to larger sizes, it simulates thicker material with deeper shadows and more pronounced lensing and refraction effects.

Lensing provides separation and communicates layering in a new way while letting content shine through underneath.

### Specular Highlights

Highlights function as the primary source of dimensionality. They follow geometry shapes and respond to device motion, behaving like environmental light reflections found in the physical world.

### Adaptive Multi-Layer Architecture

The material comprises multiple adaptive layers adjusting automatically based on background content:
- Shadows increase opacity over text but decrease over plain backgrounds, maintaining readability
- The system maintains contrast automatically
- It shifts between light and dark modes seamlessly
- Larger elements cast deeper shadows with richer lensing; smaller components scale proportionally

### Tinting

Liquid Glass introduces a new way of tinting elements that respects the material's principles. Selecting a color generates a range of tones mapped to content brightness underneath the tinted element. It draws inspiration from colored glass in reality: changing hue, brightness, and saturation depending on what is behind it.

### Interaction Glow

When touched or interacted with, contact triggers illumination radiating across elements and extending into adjacent glass surfaces, creating organic, blended interactions.

### Environmental Intelligence

- Real-time light bending (lensing)
- Specular highlights responding to device motion
- Adaptive shadows
- Automatic contrast maintenance
- Automatic light/dark mode adaptation

---

## 3. SwiftUI APIs

### 3.1 The `glassEffect()` Modifier

The primary API for applying Liquid Glass to custom views.

```swift
func glassEffect<S: Shape>(
    _ glass: Glass = .regular,
    in shape: S = .capsule,
    isEnabled: Bool = true
) -> some View
```

**Glass Variants:**

| Variant | Description | Use Case |
|---------|-------------|----------|
| `.regular` | Default; medium transparency; full adaptivity | Most UI elements |
| `.clear` | High transparency; requires dimming layer | Media-rich backgrounds |
| `.identity` | No effect applied; conditional disable | Accessibility fallbacks |

**Basic usage:**
```swift
Text("Hello, Liquid Glass")
    .padding()
    .glassEffect()
```

**With custom shape:**
```swift
Text("Custom Glass")
    .padding()
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
```

**Available shapes:**
```swift
.glassEffect(.regular, in: .capsule)       // Default
.glassEffect(.regular, in: .circle)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
.glassEffect(.regular, in: .ellipse)
.glassEffect(.regular, in: .rect(cornerRadius: .containerConcentric))
```

### 3.2 Glass Modifiers

**Tinting** -- convey semantic meaning (primary action, state), not decoration:
```swift
.glassEffect(.regular.tint(.blue))
.glassEffect(.regular.tint(.purple.opacity(0.6)))
```

**Interactive mode** (iOS only -- adds scaling, bouncing, shimmer, touch-point illumination):
```swift
Button("Tap Me") { }
    .glassEffect(.regular.interactive())
```

**Method chaining:**
```swift
.glassEffect(.regular.tint(.orange).interactive())
```

### 3.3 Button Styles

**`.buttonStyle(.glass)`** -- Translucent, frosted layer. Button appears to float above background. Includes system bounce animations. Use for secondary or common actions.

```swift
Button("Add", action: addItem)
    .buttonStyle(.glass)
```

**`.buttonStyle(.glassProminent)`** -- Opaque (no background show-through) yet still reacts like glass. Use for primary actions requiring stronger visual emphasis.

```swift
Button("Save") { save() }
    .buttonStyle(.glassProminent)
```

Key difference: `.glass` is translucent and clear-like; `.glassProminent` is opaque but still reactive.

### 3.4 GlassEffectContainer

Combines multiple Liquid Glass shapes into a unified composition. Critical because **glass cannot sample other glass** -- the container provides a shared sampling region.

```swift
GlassEffectContainer {
    HStack(spacing: 20) {
        Image(systemName: "pencil")
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive())

        Image(systemName: "eraser")
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive())
    }
}
```

**With spacing control** (controls morphing threshold -- elements within this distance visually blend):
```swift
GlassEffectContainer(spacing: 40.0) {
    ForEach(icons) { icon in
        IconView(icon)
            .glassEffect()
    }
}
```

Benefits:
- Improves rendering performance via shared sampling region
- Enables morphing transitions between glass elements
- Creates visual blending when elements are positioned close together

### 3.5 Morphing Transitions with `glassEffectID`

Requirements:
1. Elements in the same `GlassEffectContainer`
2. Each view has `glassEffectID` with a shared namespace
3. Views conditionally shown/hidden trigger morphing
4. Animation applied to state changes

```swift
func glassEffectID<ID: Hashable>(
    _ id: ID,
    in namespace: Namespace.ID
) -> some View
```

Example:
```swift
struct MorphingExample: View {
    @State private var isExpanded = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 30) {
            Button(isExpanded ? "Collapse" : "Expand") {
                withAnimation(.bouncy) {
                    isExpanded.toggle()
                }
            }
            .glassEffect()
            .glassEffectID("toggle", in: namespace)

            if isExpanded {
                Button("Action 1") { }
                    .glassEffect()
                    .glassEffectID("action1", in: namespace)

                Button("Action 2") { }
                    .glassEffect()
                    .glassEffectID("action2", in: namespace)
            }
        }
    }
}
```

### 3.6 Background Extension Effect

Extends and mirrors content behind the control layer (sidebars, toolbars) with blur.

```swift
Image(recipe.imageName)
    .resizable()
    .scaledToFill()
    .backgroundExtensionEffect()
```

Primary use case: detail views in `NavigationSplitView` where the image extends behind the floating sidebar.

```swift
struct RecipeDetailView: View {
    let recipe: Recipe

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Image(recipe.imageName)
                    .resizable()
                    .scaledToFill()
                    .backgroundExtensionEffect()

                RecipeNameAndDescription(recipe: recipe)
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}
```

### 3.7 Scroll Edge Effect Style

Controls how scroll views behave at edges that intersect with safe areas (tab bars, toolbars).

```swift
.scrollEdgeEffectStyle(.soft, for: .all)
```

| Style | Description | Use Case |
|-------|-------------|----------|
| `.automatic` | System-determined (default) | Most apps |
| `.hard` | Sharp edge, visible dividing line | Discrete UI boundaries |
| `.soft` | Rounded, diffused overscroll | Fluid, immersive experiences |

Chain different styles for different edges:
```swift
.scrollEdgeEffectStyle(.soft, for: .top)
.scrollEdgeEffectStyle(.hard, for: .bottom)
```

### 3.8 Toolbar APIs

**ToolbarSpacer** -- creates spacing between toolbar item groups:
```swift
.toolbar {
    ToolbarItem { HomeLink() }
    ToolbarSpacer(.fixed)
    ToolbarItem { FavoriteButton() }
    ToolbarItem { ProfileButton() }
    ToolbarSpacer(.flexible)
    ToolbarItem { SearchToggle() }
}
```

**Toolbar item grouping:**
```swift
ToolbarItemGroup(placement: .primaryAction) {
    Button("Draw", systemImage: "pencil") { }
    Button("Erase", systemImage: "eraser") { }
}
```

**Tinting and badging toolbar items:**
```swift
Button("Done", systemImage: "checkmark") { }
    .tint(.red)
    .badge(3)
```

Toolbars automatically receive Liquid Glass styling. No code changes needed for basic adoption. Use monochrome tinting to reduce visual noise; apply `.tint()` only for intentional color overrides.

### 3.9 Control Sizes (macOS)

| Size | Shape | Use Case |
|------|-------|----------|
| Mini | Rounded rectangle | Compact inspector panels |
| Small | Rounded rectangle | Dense layouts |
| Medium | Rounded rectangle | Standard controls |
| Large | Capsule | Emphasis in spacious areas |
| Extra Large | Capsule + Liquid Glass | Maximum emphasis |

```swift
Button("Large Action") { }
    .controlSize(.large)
    .buttonStyle(.glass)

Button("Extra Large") { }
    .controlSize(.extraLarge)
    .buttonStyle(.glassProminent)
```

### 3.10 Concentric Corner Radius

Build views that automatically maintain concentricity with their container:

```swift
CustomControl()
    .background(.tint, in: .rect(cornerRadius: .containerConcentric))
```

This ensures inner rounded rectangles align perfectly with outer container corners, matching hardware form factors.

---

## 4. macOS-Specific Guidance

### Window Chrome

- Window corners are more rounded in macOS Tahoe
- The entire window shape has been altered to align with the Liquid Glass design
- The menu bar is **fully transparent by default** (users can restore a solid background in System Settings > Menu Bar > "Show menu bar background")

### Toolbars

- Toolbar elements are placed on a glass material and **float above content**
- AppKit/SwiftUI automatically groups multiple toolbar buttons together on one piece of glass
- Different control types (segmented controls, pop-up buttons, search) are separated into their own glass elements
- The toolbar glass adaptively switches between light and dark appearance based on scrolled content brightness
- Content flows edge-to-edge, with Liquid Glass elements floating atop

### Sidebars

- `NavigationSplitView` now presents a **floating Liquid Glass sidebar**
- The sidebar receives ambient reflection automatically
- Use `.backgroundExtensionEffect()` to extend detail view images behind the sidebar with blur
- The `sidebarAdaptable` tab view style presents tabs in a sidebar overlay and displays the window title

### Scroll Edge Effects

The system applies a visual effect where glass overlaps with content. Customize with `scrollEdgeEffectStyle`:
```swift
ScrollView {
    // content
}
.scrollEdgeEffectStyle(.soft, for: .all)
```

### NavigationSplitView Example (macOS)

```swift
struct ContentView: View {
    @State private var selection: Item?

    var body: some View {
        NavigationSplitView {
            List(items, selection: $selection) { item in
                NavigationLink(value: item) {
                    Label(item.name, systemImage: item.icon)
                }
            }
            .navigationTitle("Items")
        } detail: {
            if let selection {
                DetailView(item: selection)
            } else {
                ContentUnavailableView("Select an item", systemImage: "sidebar.left")
            }
        }
    }
}
```

The `NavigationSplitView` automatically receives the floating glass sidebar treatment when compiled with Xcode 26 for macOS 26. No additional modifiers are needed for the glass sidebar effect.

### Toolbar Example (macOS)

```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                // content
            }
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Draw", systemImage: "pencil") { }
                    Button("Erase", systemImage: "eraser") { }
                }
                ToolbarSpacer(.flexible)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") { }
                }
            }
        }
    }
}
```

### macOS Window Styling

```swift
// Translucent window background using material
.containerBackground(.ultraThinMaterial, for: .window)
```

The unified toolbar style combines the toolbar and window title bar into a single element. Content can blur behind toolbars and title bars when using `ScrollView`.

### Backward Compatibility

```swift
struct ToolbarLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26, *) {
            Label(configuration)
        } else {
            Label(configuration)
                .labelStyle(.titleOnly)
        }
    }
}

extension LabelStyle where Self == ToolbarLabelStyle {
    static var toolbar: Self { .init() }
}
```

---

## 5. Color, Typography, and Icons

### Color

- **Automatic vibrancy.** SwiftUI automatically uses vibrant text colors that adapt to maintain legibility against colorful backgrounds.
- **Tinting draws from colored glass.** Selecting a color generates a range of tones mapped to content brightness underneath. Hue, brightness, and saturation change depending on what is behind the element.
- **Tint only for meaning.** Apply selective color only to primary actions, call-to-action buttons, and functionally significant items. Avoid universal tinting.
- **Six variants.** Default and Clear in light mode, dark mode, and tinted mode.

```swift
// Tinting for semantic meaning
.glassEffect(.regular.tint(.blue))    // Primary action
.glassEffect(.regular.tint(.red))     // Destructive action
.glassEffect(.regular)                // Standard, no tint
```

### Typography

- **San Francisco** has been updated to dynamically scale the weight, width, and height of each numeral to nestle into scenes.
- Text on glass automatically receives vibrant treatment, adjusting color and brightness based on background.
- Use high-contrast foreground styles for text on glass:

```swift
Text("Glass Text")
    .font(.title)
    .bold()
    .foregroundStyle(.white)  // High contrast
    .padding()
    .glassEffect()
```

- Most SF families come with weights spanning from Ultralight to Black.
- Optical Sizes automatically adjust design features based on point size.

### Icons

- **Icon Composer** is Apple's new tool for creating multi-layer Liquid Glass app icons.
- A single layered structure provides Default, Dark, and Mono appearance modes across all platforms.
- Icons respond to dynamic lighting effects with specular highlights, blur, translucency, and shadows.

**Icon Layer Guidelines:**
- Separate foreground and background layers
- Isolate color zones into distinct layers
- Ensure foreground layers have transparent backgrounds
- Convert text to outlines for SVG exports
- Avoid sharp corners -- light navigates better on rounded corners
- Do not overcrowd designs with conflicting light effects

**Dark Mode Icons:**
- Adjust fills to prevent elements fading into dark backgrounds
- Boost contrast in key areas
- Ensure recognizability across appearance modes

**Mono/Clear Mode Icons:**
- Set one layer containing full white
- Map other colors to grayscale
- Icon Composer provides automatic conversion with manual tuning options

**Export:**
- Use SVG for vectors (maintains scalability)
- Use PNG for rasterized images with effects
- Do not include platform masks in exports

### SF Symbols on Glass

```swift
Image(systemName: "heart.fill")
    .font(.largeTitle)
    .foregroundStyle(.white)
    .frame(width: 60, height: 60)
    .glassEffect(.regular.interactive())

Label("Settings", systemImage: "gear")
    .labelStyle(.iconOnly)
    .padding()
    .glassEffect()
```

---

## 6. Code Examples

### Complete macOS App Structure

```swift
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
        } detail: {
            if let selectedItem {
                DetailView(item: selectedItem)
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left"
                )
            }
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            NavigationLink(value: item) {
                Label(item.title, systemImage: item.icon)
            }
        }
        .navigationTitle("My App")
    }
}

struct DetailView: View {
    let item: SidebarItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hero image extending behind sidebar
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
                    .backgroundExtensionEffect()

                // Content
                Text(item.title)
                    .font(.largeTitle)
                    .bold()

                Text(item.description)
                    .font(.body)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle(item.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") { }
            }
            ToolbarSpacer(.flexible)
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark") { }
                    .tint(.blue)
            }
        }
    }
}
```

### Custom Glass Floating Action Button

```swift
struct FloatingActionButton: View {
    @State private var isExpanded = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 30) {
            if isExpanded {
                Button {
                    // action
                } label: {
                    Label("New Document", systemImage: "doc.badge.plus")
                        .labelStyle(.iconOnly)
                        .frame(width: 50, height: 50)
                }
                .glassEffect(.regular.interactive())
                .glassEffectID("newDoc", in: namespace)

                Button {
                    // action
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .labelStyle(.iconOnly)
                        .frame(width: 50, height: 50)
                }
                .glassEffect(.regular.interactive())
                .glassEffectID("import", in: namespace)
            }

            Button {
                withAnimation(.bouncy) {
                    isExpanded.toggle()
                }
            } label: {
                Label("Add", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white)
            }
            .glassEffect(.regular.tint(.blue).interactive())
            .glassEffectID("main", in: namespace)
        }
    }
}
```

### Glass Toolbar with Badge

```swift
struct DashboardView: View {
    var body: some View {
        ScrollView {
            DashboardContent()
        }
        .toolbar {
            ToolbarItem { HomeLink() }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Button("Notifications", systemImage: "bell") { }
                    .badge(5)
            }
            ToolbarItem {
                Button("Profile", systemImage: "person.circle") { }
            }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Button("Search", systemImage: "magnifyingglass") { }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}
```

### Conditional Glass Effect for Accessibility

```swift
struct AccessibleGlassView: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Text("Accessible")
            .padding()
            .glassEffect(reduceTransparency ? .identity : .regular)
    }
}
```

### Search with Glass Design

```swift
// Toolbar-based search
NavigationStack {
    List { /* content */ }
}
.searchable(text: $searchText)

// Dedicated search tab
TabView {
    Tab(role: .search) {
        NavigationStack {
            SearchContent()
        }
    }
}
.searchable(text: $searchText)
```

---

## 7. Best Practices

### DO

- **Use standard app structures.** NavigationSplitView, toolbars, search placements, and standard controls automatically adopt Liquid Glass.
- **Adopt system components first.** They automatically get Liquid Glass styling when compiled with Xcode 26.
- **Use `.glassEffect()` for custom controls** that need the glass appearance.
- **Group glass elements** in a `GlassEffectContainer` for visual blending and performance.
- **Tint only for semantic meaning** -- primary actions, state indicators, call-to-action.
- **Test across appearance modes** -- light, dark, tinted.
- **Remove explicit background colors** before applying glass effects.
- **Use `.backgroundExtensionEffect()`** on detail view images that should extend behind sidebars.
- **Prioritize symbol-based buttons** over text labels in toolbars.
- **Let the system handle accessibility** -- Liquid Glass automatically adapts to Reduce Transparency, Increase Contrast, and Reduce Motion.
- **Use concentric corner radii** for nested elements: `.rect(cornerRadius: .containerConcentric)`.
- **Maintain 4.5:1 contrast ratio** for text on glass surfaces.
- **Test with varied wallpapers and backgrounds** for legibility.

### DO NOT

- **Never apply Liquid Glass to content.** It is only for the navigation layer (toolbars, tab bars, sidebars, floating controls). Lists, tables, media are content.
- **Never mix Regular and Clear variants.** They should never be mixed as they each have their own characteristics.
- **Never layer glass on glass.** Glass cannot sample other glass. Use `GlassEffectContainer` to combine elements.
- **Never use tint purely for decoration.** Tint conveys meaning; decorative tinting dilutes visual hierarchy.
- **Never apply heavy blur to frequently updated content.** Performance cost.
- **Never use multiple nested glass elements.** Performance and readability issues.
- **Never ignore legibility.** Liquid Glass applied incorrectly worsens readability.
- **Never bypass system frameworks** when accessibility adaptations are needed.
- **Never use custom backgrounds that interfere** with Liquid Glass effects or scroll edge interactions.
- **Never create a mixed experience** -- if you update some custom components to glass, update all of them. Partial adoption looks jarring.

### Clear Variant Requirements (ALL must be met)

1. Element sits over media-rich content
2. Content will not be negatively affected by the dimming layer
3. Content above the glass is bold and bright

### Performance Considerations

- Use `GlassEffectContainer` for shared sampling regions (better performance)
- Apply `backdrop-filter` / blur sparingly
- Test glass effects across lower-end devices
- Optimize blur radius relative to content complexity
- Avoid applying glass effects to frequently re-rendered content

---

## 8. WWDC Sessions and Resources

### Key WWDC 2025 Sessions

| Session | Title | Focus |
|---------|-------|-------|
| 219 | [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/) | Design philosophy, lensing, tinting, core concepts |
| 356 | [Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/) | Hierarchy, harmony, consistency, control sizing |
| 323 | [Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/) | SwiftUI implementation, toolbars, sidebar, code |
| 310 | [Build an AppKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/310/) | macOS NSWindow, NSToolbar, AppKit APIs |
| 284 | Build a UIKit app with the new design | UIKit implementation |
| 361 | [Create icons with Icon Composer](https://developer.apple.com/videos/play/wwdc2025/361/) | Multi-layer icon design tool |

### Apple Developer Documentation

- [Liquid Glass Overview](https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [GlassButtonStyle](https://developer.apple.com/documentation/swiftui/glassbuttonstyle)
- [Glass type](https://developer.apple.com/documentation/swiftui/glass)
- [Landmarks: Building an app with Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Landmarks-Building-an-app-with-Liquid-Glass)
- [Landmarks: Refining glass effect in toolbars](https://developer.apple.com/documentation/SwiftUI/Landmarks-Refining-the-system-provided-glass-effect-in-toolbars)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Apple Design Resources](https://developer.apple.com/design/resources/)
- [Icon Composer](https://developer.apple.com/icon-composer/)
- [New Design Gallery](https://developer.apple.com/design/new-design-gallery/)

### Community References

- [Liquid Glass SwiftUI Reference (GitHub)](https://github.com/conorluddy/LiquidGlassReference)
- [Awesome Liquid Glass (GitHub)](https://github.com/carolhsiaoo/awesome-liquid-glass)

---

## Quick-Reference API Cheat Sheet

```
-- Glass Effect --
.glassEffect()                                    // Default capsule glass
.glassEffect(.regular, in: .circle)               // Custom shape
.glassEffect(.clear, in: .capsule)                // Clear variant
.glassEffect(.regular.tint(.blue))                // Tinted
.glassEffect(.regular.interactive())              // Interactive (iOS)
.glassEffect(.regular.tint(.red).interactive())   // Chained
.glassEffect(.identity)                           // Disabled/passthrough

-- Button Styles --
.buttonStyle(.glass)                              // Translucent glass
.buttonStyle(.glassProminent)                     // Opaque glass (primary)

-- Container --
GlassEffectContainer { ... }                      // Group glass elements
GlassEffectContainer(spacing: 40) { ... }         // Custom morph threshold

-- Morphing --
.glassEffectID("id", in: namespace)               // Enable morph transitions

-- Background Extension --
.backgroundExtensionEffect()                      // Extend + blur behind controls

-- Scroll Edge --
.scrollEdgeEffectStyle(.soft, for: .all)           // Soft overscroll
.scrollEdgeEffectStyle(.hard, for: .bottom)        // Hard edge

-- Toolbar --
ToolbarSpacer(.fixed)                             // Fixed spacing
ToolbarSpacer(.flexible)                          // Flexible spacing

-- Corner Concentricity --
.rect(cornerRadius: .containerConcentric)         // Concentric corners

-- Control Size (macOS) --
.controlSize(.mini)                               // Mini (rounded rect)
.controlSize(.small)                              // Small (rounded rect)
.controlSize(.regular)                            // Medium (rounded rect)
.controlSize(.large)                              // Large (capsule)
.controlSize(.extraLarge)                         // XL (capsule + glass)
```
