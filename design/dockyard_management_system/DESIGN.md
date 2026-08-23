---
name: Dockyard Management System
colors:
  surface: '#111316'
  surface-dim: '#111316'
  surface-bright: '#37393d'
  surface-container-lowest: '#0c0e11'
  surface-container-low: '#1a1c1f'
  surface-container: '#1e2023'
  surface-container-high: '#282a2d'
  surface-container-highest: '#333538'
  on-surface: '#e2e2e6'
  on-surface-variant: '#bcc8d0'
  inverse-surface: '#e2e2e6'
  inverse-on-surface: '#2f3034'
  outline: '#87929a'
  outline-variant: '#3d484f'
  surface-tint: '#70d2ff'
  primary: '#70d2ff'
  on-primary: '#003547'
  primary-container: '#0db7ed'
  on-primary-container: '#00445b'
  inverse-primary: '#006686'
  secondary: '#adcbda'
  on-secondary: '#163440'
  secondary-container: '#304d5a'
  on-secondary-container: '#9fbdcc'
  tertiary: '#d4bbff'
  on-tertiary: '#3f0f81'
  tertiary-container: '#bc97ff'
  on-tertiary-container: '#4e2490'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#c0e8ff'
  primary-fixed-dim: '#70d2ff'
  on-primary-fixed: '#001e2b'
  on-primary-fixed-variant: '#004d66'
  secondary-fixed: '#c9e7f7'
  secondary-fixed-dim: '#adcbda'
  on-secondary-fixed: '#001f2a'
  on-secondary-fixed-variant: '#2e4b57'
  tertiary-fixed: '#ebdcff'
  tertiary-fixed-dim: '#d4bbff'
  on-tertiary-fixed: '#260058'
  on-tertiary-fixed-variant: '#572e99'
  background: '#111316'
  on-background: '#e2e2e6'
  surface-variant: '#333538'
typography:
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  code-md:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
  label-caps:
    fontFamily: Hanken Grotesk
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  container-padding: 24px
  gutter: 16px
  sidebar-width: 260px
  sidebar-collapsed: 64px
  density-comfortable: 12px
  density-compact: 8px
---

## Brand & Style

The design system is engineered for high-performance container orchestration and infrastructure management. It prioritizes utility, data density, and technical precision, evoking a sense of "mission control" for DevOps engineers and system administrators.

The aesthetic blends **Modern Corporate** reliability with a **Technical/Developer-centric** edge. It utilizes a systematic approach to information architecture, ensuring that complex hierarchical data (containers, images, volumes) remains legible and actionable. The interface remains quiet and functional, allowing the status-driven color system to communicate health and urgency without visual noise.

## Colors

This design system uses a dark-dominant palette to reduce eye strain during prolonged monitoring sessions, while maintaining a full set of light-mode tokens for accessibility.

- **Primary Blue (#0DB7ED):** Reserved for primary actions, active navigation states, and the "Docker" identity.
- **Surface Colors:** Built on a scale of neutral grays. `surface-0` is the deep background (#121417), while `surface-1` through `surface-4` use subtle shifts in lightness to create container-on-container depth.
- **Semantic Logic:**
  - **Success:** Running / Healthy states.
  - **Warning:** Transitioning / Restarting / High Resource usage.
  - **Error:** Stopped (unplanned) / Failed / Alert.
  - **Inactive:** Stopped (planned) / Paused / Unused images.

## Typography

The system utilizes a dual-font strategy:
1. **Hanken Grotesk** handles the UI layer. It is a sharp, contemporary sans-serif that provides excellent legibility in high-density data tables and sidebars.
2. **JetBrains Mono** is used for all technical strings. This includes Container IDs, Image Hashes, Pathnames, CLI logs, and environment variables. 

**Usage Guidelines:**
- Use `label-caps` for table headers and section subtitles to provide clear visual anchors.
- `code-sm` should be used for status badges containing IDs to maximize horizontal space.
- All log viewers and terminal emulators must strictly use `code-md`.

## Layout & Spacing

The design system is optimized for a **1440x900** workspace. It employs a fixed-fluid hybrid model:
- **Navigation:** A persistent, collapsible left sidebar.
- **Content:** A fluid main area that uses a 12-column grid system for dashboard widgets and a full-width container for data tables.
- **Density:** Default to "Compact" (8px spacing) for data tables and list views to ensure maximum information visibility without scrolling. Use "Comfortable" (12px) for settings pages and form layouts.

**Breakpoints:**
- **Desktop (1440+):** Full sidebar, 12-column grid.
- **Tablet (768-1439):** Collapsed sidebar (icons only), 8-column grid.
- **Mobile (<767):** Bottom navigation or hamburger menu, single column.

## Elevation & Depth

Based on Material Design 3 logic, depth is conveyed through **Tonal Elevation** rather than heavy drop shadows. 

- **Level 0 (Background):** The primary canvas color.
- **Level 1 (Cards/Tables):** Surfaces that sit directly on the background. Use a subtle border (1px, low opacity) to define boundaries.
- **Level 2 (Modals/Popovers):** Elements that float. Use a soft, 16px blur shadow with 20% opacity of the background color to create separation.
- **Interactive States:** On hover, technical elements should utilize a "glow" or "rim-light" effect using the primary or semantic color (e.g., a 1px primary-colored border on a focused input).

## Shapes

The shape language is "Soft" (4px radius) to maintain a professional, engineered feel. 

- **Small Components:** Buttons, inputs, and checkboxes use a **4px (0.25rem)** radius.
- **Large Components:** Cards and dashboard widgets use a **8px (0.5rem)** radius.
- **Status Pills:** Use a fully rounded/pill shape (999px) to distinguish them from interactive buttons.
- **Selection Indicators:** Use a vertical bar (2px wide) on the left side of active navigation or list items to indicate focus.

## Components

### Status Badges
Status badges are critical for the 'Dockyard' experience.
- **Structure:** 1px solid border, 10% opacity background of the semantic color, and 100% opacity text.
- **Variants:** 
  - `Running`: Green text/border.
  - `Stopped`: Gray text/border.
  - `Restarting`: Yellow text/border.
  - `Error/Exited`: Red text/border.

### Data Tables
- **Header:** Sticky, using `label-caps` typography with a subtle bottom border.
- **Rows:** Alternating zebra striping (optional) or 1px bottom border. Hover state should highlight the entire row in a subtle primary-tinted gray.
- **Density:** Cell padding should be 8px vertical, 12px horizontal.

### Input Fields
- **Style:** Outlined. In dark mode, the outline is a mid-gray, turning primary blue on focus. 
- **Monospace Inputs:** Any field requiring a container name, image tag, or volume path must use the `code-md` font.

### Buttons
- **Primary:** Solid Primary Blue with white/dark text.
- **Secondary:** Outlined with primary blue text.
- **Ghost:** No background or border, used for table row actions (e.g., Stop, Restart, Delete icons).

### Collapsible Sidebar
- **State:** Expanded by default. Contains high-level categories: Dashboard, Containers, Images, Volumes, Networks, and Settings.
- **Active State:** Primary Blue background at 10% opacity with a 2px solid primary left-accent bar.