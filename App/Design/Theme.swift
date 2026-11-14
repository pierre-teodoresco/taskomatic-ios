import SwiftUI

enum Theme {
  static let canvas = Color("Canvas")
  static let surface = Color("Surface")
  static let raised = Color("Raised")
  static let ink = Color("Ink")
  static let secondary = Color("Secondary")
  static let accent = Color("AccentColor")
  static let onAccent = Color("OnAccent")
  static let accentSoft = Color("AccentSoft")
  static let line = Color("Line")
  /// Background of screens built on a plain `List`, matching the system row background so
  /// rows blend in and a swiped row reads as a rounded platter, as in Messages and Mail.
  static let listCanvas = Color(uiColor: .systemBackground)

  static let pagePadding: CGFloat = 20
  /// Outer radius of content cards. Nested shapes subtract their inset to stay concentric.
  static let corner: CGFloat = 26
  /// Horizontal inset of the floating control layer from the screen edges.
  static let barPadding: CGFloat = 16

  static func card(_ radius: CGFloat = corner) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: radius, style: .continuous)
  }
}

// MARK: - Liquid Glass

// Liquid Glass surfaces belong to the control layer that floats above content (bars, floating
// buttons, transient banners). Content cards stay opaque; buttons inside them may use glass
// styles. Before iOS 26 the same controls fall back to a material with a hairline so the
// hierarchy is unchanged.

extension View {
  /// Applies Liquid Glass behind the view, or a material fallback before iOS 26.
  @ViewBuilder
  func glassLayer<S: Shape>(in shape: S, interactive: Bool = false, tint: Color? = nil)
    -> some View
  {
    if #available(iOS 26, *) {
      glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
    } else if let tint {
      background(tint, in: shape)
    } else {
      background(.regularMaterial, in: shape)
        .overlay(shape.stroke(Theme.line, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
  }

  /// Glass button style; bordered system styles before iOS 26.
  @ViewBuilder
  func glassButtonStyle(prominent: Bool = false) -> some View {
    if #available(iOS 26, *) {
      if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
    } else {
      if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
    }
  }

  /// Marks the primary toolbar action of a sheet as prominent glass on iOS 26.
  @ViewBuilder
  func prominentToolbarAction() -> some View {
    if #available(iOS 26, *) {
      buttonStyle(.glassProminent)
    } else {
      fontWeight(.semibold)
    }
  }

  /// A bottom bar that floats over scrolling content with the system scroll edge effect.
  @ViewBuilder
  func floatingBottomBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
    if #available(iOS 26, *) {
      safeAreaBar(edge: .bottom, spacing: 0, content: bar)
    } else {
      safeAreaInset(edge: .bottom, spacing: 0) { bar().background(.bar) }
    }
  }
}

/// Groups neighbouring glass shapes so they blend and morph together on iOS 26.
struct GlassGroup<Content: View>: View {
  var spacing: CGFloat? = nil
  @ViewBuilder var content: Content

  var body: some View {
    if #available(iOS 26, *) {
      GlassEffectContainer(spacing: spacing) { content }
    } else {
      content
    }
  }
}

/// Sheet toolbar label: a symbol on iOS 26 (system convention), the title text before.
/// The title always remains the accessibility label.
struct SheetActionLabel: View {
  let title: String
  let symbol: String
  /// Pair with `prominentToolbarAction()`: the accent background needs `OnAccent` for contrast.
  var prominent = false
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    if #available(iOS 26, *) {
      Label(title, systemImage: symbol).labelStyle(.iconOnly)
        .foregroundStyle(
          prominent && isEnabled ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(.primary))
    } else {
      Text(title)
    }
  }
}

// MARK: - Shared controls

struct Surface<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content
      .background(Theme.surface, in: Theme.card())
      .overlay(Theme.card().strokeBorder(Theme.line, lineWidth: 0.5))
  }
}

struct PrimaryButton: View {
  let title: String
  var symbol: String? = nil
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if let symbol { Image(systemName: symbol) }
        Text(title)
      }
      .font(.body.weight(.semibold))
      .foregroundStyle(Theme.onAccent)
      .frame(maxWidth: .infinity)
    }
    .glassButtonStyle(prominent: true)
    .buttonBorderShape(.capsule)
    .controlSize(.large)
  }
}

struct SelectionRow: View {
  let title: String
  let isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Text(title)
          .font(.body.weight(isSelected ? .medium : .regular))
        Spacer(minLength: 12)
        Image(systemName: "checkmark")
          .font(.body.weight(.semibold))
          .opacity(isSelected ? 1 : 0)
          .accessibilityHidden(true)
      }
      .foregroundStyle(isSelected ? Theme.accent : Theme.ink)
      .padding(18)
      .frame(maxWidth: .infinity, minHeight: 54)
      .background(isSelected ? Theme.accentSoft : Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

struct SettingsActionRow: View {
  let title: String
  let symbol: String
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: symbol).frame(width: 24)
        Text(title).multilineTextAlignment(.leading)
        Spacer(minLength: 4)
        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
          .accessibilityHidden(true)
      }
      .font(.subheadline.weight(.medium)).foregroundStyle(Theme.accent)
      .padding(.horizontal, 20).padding(.vertical, 14)
      .frame(maxWidth: .infinity, minHeight: 52)
      .contentShape(Rectangle())
    }.buttonStyle(.plain)
  }
}

struct BrandMark: View {
  var size: CGFloat = 28
  var body: some View {
    Image(systemName: "checkmark")
      .font(.system(size: size * 0.47, weight: .bold))
      .foregroundStyle(Theme.onAccent)
      .frame(width: size, height: size)
      .background(
        Theme.accent.gradient,
        in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
      )
      .accessibilityHidden(true)
  }
}

struct SectionCaption: View {
  let title: String
  var body: some View {
    // iOS 26 section headers are sentence case and heavier rather than small caps.
    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondary)
      .padding(.leading, 4)
  }
}
