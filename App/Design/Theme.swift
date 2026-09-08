import SwiftUI

enum Theme {
  static let canvas = Color("Canvas")
  static let surface = Color("Surface")
  static let raised = Color("Raised")
  static let ink = Color("Ink")
  static let secondary = Color("Secondary")
  static let accent = Color("AccentColor")
  static let accentSoft = Color("AccentSoft")
  static let line = Color("Line")

  static let pagePadding: CGFloat = 24
  static let corner: CGFloat = 20
}

struct Surface<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content
      .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner))
      .overlay(
        RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(Theme.line, lineWidth: 0.5))
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
      .frame(maxWidth: .infinity, minHeight: 52)
      .foregroundStyle(.white)
      .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(.plain)
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

struct IconButton: View {
  let symbol: String
  let label: String
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(Theme.ink)
        .frame(width: 44, height: 44)
        .background(Theme.surface, in: Circle())
        .overlay(Circle().strokeBorder(Theme.line, lineWidth: 0.5))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

struct BrandMark: View {
  var size: CGFloat = 28
  var body: some View {
    Image(systemName: "checkmark")
      .font(.system(size: size * 0.47, weight: .bold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(Theme.accent.gradient, in: RoundedRectangle(cornerRadius: size * 0.29))
      .accessibilityHidden(true)
  }
}

struct SectionCaption: View {
  let title: String
  var body: some View {
    Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondary)
      .textCase(.uppercase).tracking(1.3)
  }
}
