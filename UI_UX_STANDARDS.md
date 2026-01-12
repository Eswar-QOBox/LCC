# 🎨 UI UX STANDARDS

## 1. Purpose

This document defines **mandatory UI/UX standards** for this project.

> Any UI that does not follow this document is not production-ready.
> 

All AI agents and developers **must read this file before implementing UI**.

---

## 2. Core UI/UX Principles (Non-Negotiable)

- **Clarity over cleverness**
- **Consistency over creativity**
- **Accessibility by default**
- **Fast, responsive, predictable interactions**
- **No visual-only feedback — always functional feedback**
- **Design for real users, not screenshots**

---

## 3. Design System Rules

### 3.1 Single Source of Truth

- One design system only
- Centralized:
    - Colors
    - Typography
    - Spacing
    - Radius
    - Shadows
    - Animation tokens

❌ No hardcoded styles inside components

❌ No one-off colors or fonts

---

### 3.2 Color System

- Semantic colors only:
    - Primary
    - Secondary
    - Success
    - Warning
    - Error
    - Background
    - Surface
    - Text (primary/secondary/disabled)

Rules:

- Contrast ratio ≥ WCAG AA
- Error states must be visually distinct
- Disabled ≠ low opacity only

---

### 3.3 Typography

- Max **2 font families**
- Defined text styles:
    - Heading (H1–H6)
    - Body
    - Caption
    - Button
    - Label

Rules:

- Line height ≥ 1.4
- No text below 12px
- Never rely on color alone for meaning

---

## 4. Layout & Spacing

### 4.1 Spacing System

- Use spacing scale only (e.g., 4, 8, 12, 16, 24, 32)
- Consistent padding inside components
- Visual rhythm must be maintained

❌ Random margins

❌ Pixel guessing

---

### 4.2 Layout Rules

- Mobile-first design
- Responsive at all breakpoints
- Content must never overflow or clip

---

## 5. Components Standards

### 5.1 Component Design

Each component MUST have:

- Default state
- Hover / focus state
- Loading state
- Disabled state
- Error state (if applicable)

❌ No missing states

❌ No invisible loading

---

### 5.2 Buttons

- Clear visual hierarchy (Primary / Secondary / Tertiary)
- Disabled buttons must explain *why* when possible
- Loading = spinner + disabled interaction

---

### 5.3 Inputs & Forms

Mandatory:

- Labels (not placeholders only)
- Inline validation messages
- Clear error recovery guidance

Rules:

- Validate on blur + submit
- Never clear user input on error
- Show success feedback after submit

---

## 6. UX Flow Standards

### 6.1 Navigation

- Predictable navigation patterns
- No hidden primary actions
- Back navigation always works

---

### 6.2 User Feedback (CRITICAL)

Every user action must have:

- Immediate visual feedback
- Clear success or failure state
- Recovery path for errors

Examples:

- Button tap → visual response ≤ 100ms
- API action → loading indicator
- Error → human-readable message

---

## 7. Loading, Empty & Error States

### 7.1 Loading States

- Skeletons preferred over spinners
- No full-screen loaders unless blocking action
- Never freeze UI

---

### 7.2 Empty States

Every empty state must:

- Explain *why* it's empty
- Suggest next action
- Be visually intentional

❌ Blank screens

---

### 7.3 Error States

- Clear, non-technical language
- Never blame the user
- Offer retry or fallback

---

## 8. Accessibility (MANDATORY)

Minimum requirements:

- Keyboard navigation
- Screen reader labels
- Focus indicators visible
- Touch targets ≥ 44px
- Color contrast compliance

❌ Accessibility as "later improvement"

---

## 9. Animations & Motion

Rules:

- Purpose-driven only
- ≤ 300ms for micro-interactions
- Reduce motion respected (OS setting)

❌ Decorative-only animations

❌ Blocking animations

---

## 10. Performance UX

- First meaningful paint ≤ 1.5s
- UI must remain interactive during data fetch
- Lazy-load heavy components
- Avoid layout shifts

---

## 11. Platform Consistency

- Follow platform conventions (iOS / Android / Web)
- No fighting native behaviors
- Gestures must feel native

---

## 12. AI Agent UI Rules

AI MUST:

1. Reuse existing components
2. Follow spacing & typography scale
3. Implement all UI states
4. Handle empty, loading, and error states
5. Ensure accessibility basics

If uncertain → STOP and ask.

---

## 13. UI Review Checklist (Before Merge)

- ✅ All states implemented
- ✅ No hardcoded styles
- ✅ Accessible labels present
- ✅ Responsive across sizes
- ✅ Error & empty states handled
- ✅ No visual regressions

---

## 14. Forbidden Practices

- Hardcoded colors / fonts
- Placeholder-only inputs
- Silent failures
- UI-only validation
- Hidden primary actions

---

## 15. Final Statement

This UI/UX standard ensures:

- Consistency
- Accessibility
- Performance
- Scalability
- Production readiness

**No shortcuts. No exceptions.**

---

## 16. Project-Specific Implementation

### Current Design System Location

- **Theme:** `lib/utils/app_theme.dart`
- **Components:** `lib/widgets/`
- **Screens:** `lib/screens/`

### Flutter-Specific Guidelines

1. **Use Theme.of(context)** for all colors
2. **Use AppTheme constants** for semantic colors
3. **Use Material 3** design tokens
4. **Implement Semantics widgets** for accessibility
5. **Use Const constructors** where possible for performance

### Color Usage

```dart
// ✅ CORRECT
Theme.of(context).colorScheme.primary
AppTheme.successColor
colorScheme.onSurface

// ❌ WRONG
Colors.blue
Color(0xFF0175C2) // Use AppTheme.primaryColor instead
```

### Spacing Usage

```dart
// ✅ CORRECT
const EdgeInsets.all(16)
const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
const SizedBox(height: 8)

// ❌ WRONG
EdgeInsets.all(15.5) // Not on spacing scale
EdgeInsets.all(13) // Not on spacing scale
```

---

**Last Updated:** January 2025  
**Version:** 1.0.0
