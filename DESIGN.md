---
name: Lush Systematic
colors:
  surface: '#f7f9fb'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  on-surface: '#191c1e'
  on-surface-variant: '#424656'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#727687'
  outline-variant: '#c2c6d8'
  surface-tint: '#0054d6'
  primary: '#0050cb'
  on-primary: '#ffffff'
  primary-container: '#0066ff'
  on-primary-container: '#f8f7ff'
  inverse-primary: '#b3c5ff'
  secondary: '#3b6566'
  on-secondary: '#ffffff'
  secondary-container: '#beebeb'
  on-secondary-container: '#426b6c'
  tertiary: '#4a5c64'
  on-tertiary: '#ffffff'
  tertiary-container: '#62757d'
  on-tertiary-container: '#f0faff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dae1ff'
  primary-fixed-dim: '#b3c5ff'
  on-primary-fixed: '#001849'
  on-primary-fixed-variant: '#003fa4'
  secondary-fixed: '#beebeb'
  secondary-fixed-dim: '#a3cfcf'
  on-secondary-fixed: '#002020'
  on-secondary-fixed-variant: '#224d4e'
  tertiary-fixed: '#d2e6ef'
  tertiary-fixed-dim: '#b6cad2'
  on-tertiary-fixed: '#0b1e24'
  on-tertiary-fixed-variant: '#374951'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#e0e3e5'
typography:
  headline-xl:
    fontFamily: Manrope
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 40px
  container-max: 1280px
---

## Brand & Style
The design system embodies a "Lush Systematic" aesthetic—a fusion of organic tranquility and rigorous data-driven precision. It targets professional environments where complex information needs to be digested without cognitive fatigue.

The style leverages **Minimalism** with a **Tactile** edge. It utilizes expansive whitespace and a structured grid to maintain order, while subtle gradients and soft surface treatments prevent the UI from feeling sterile. The emotional goal is to evoke a sense of focused calm, reliability, and high-velocity clarity.

## Colors
The palette is grounded in a deep, forest-inspired secondary green (`#0F3D3E`) to provide a sense of stability. The primary accent is a **Vibrant Blue** (`#0066FF`), replacing the previous amber to inject energy and modern technicality into high-priority zones.

- **Primary (Vibrant Blue):** Reserved for high-priority analytics cards, primary call-to-action buttons, and active navigation indicators.
- **Secondary (Deep Teal/Green):** Used for structural elements, headers, and primary text to maintain the "Lush" foundation.
- **Tertiary (Soft Sky):** A background wash for secondary containers and subtle highlights.
- **Neutral:** A range of cool slates and off-whites to ensure the interface remains airy.

## Typography
The typography strategy balances modern approachability with technical precision. 

- **Manrope** is used for headlines to provide a warm, geometric feel that remains professional.
- **Inter** handles the bulk of body content for its supreme legibility and systematic neutral tone.
- **JetBrains Mono** is utilized for metadata, labels, and small data points to reinforce the "Systematic" aspect of the brand, suggesting accuracy and data-integrity.

## Layout & Spacing
The design system utilizes a **Fluid Grid** model based on an 8px root scale. 

- **Desktop:** A 12-column grid with 24px gutters. Content is housed in a max-width container of 1280px to prevent excessive line lengths.
- **Tablet:** 8-column grid with 16px margins.
- **Mobile:** 4-column grid with 16px margins. 

Spacing between sections should be generous (64px+) to maintain the "Lush" feeling of openness. Functional components should use tight internal padding (12px-16px) to keep data density efficient.

## Elevation & Depth
Depth is communicated through **Tonal Layers** and **Ambient Shadows**. 

Instead of heavy black shadows, this design system uses soft, diffused shadows tinted with the secondary green color (e.g., 10% opacity `#0F3D3E`). 
- **Level 1 (Base):** Neutral background.
- **Level 2 (Cards):** White background with a 1px border (`#E2E8F0`) or a very soft shadow.
- **Level 3 (Popovers/Modals):** High diffusion shadows (30px blur) to create a floating effect.

High-priority analytics cards use the primary blue as a subtle top-border accent or a very low-opacity background tint to elevate them from the standard grid.

## Shapes
The shape language is consistently **Rounded**. 

Standard components (inputs, buttons, cards) utilize a 0.5rem (8px) corner radius. This softens the systematic grid and aligns with the organic "Lush" narrative. Large-scale containers like modals or hero sections may scale up to `rounded-xl` (24px) to emphasize the architectural flow of the interface.

## Components
- **Buttons:** Primary buttons are solid **Vibrant Blue** with white text. Secondary buttons use a ghost style with the **Deep Teal** outline.
- **Analytics Cards:** High-priority cards feature a 4px top stroke of Vibrant Blue and use Manrope Bold for primary metrics.
- **Navigation:** Active states in sidebars or top-navs are indicated by a Vibrant Blue vertical pill or underline and a shifted font weight (600).
- **Input Fields:** Use a subtle Slate-100 fill and a 1px border. On focus, the border transitions to Vibrant Blue with a soft 2px outer glow.
- **Chips:** Small, pill-shaped tags using the `label-md` mono font. Status-specific chips use muted green/red/blue tints with high-contrast text.
- **Lists:** Clean rows with 1px horizontal dividers. Interactive list items should have a subtle Sky Blue hover state.