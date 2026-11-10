# Bulkhead workspace design system

Bulkhead is a desktop operations workspace. The layout prioritizes identifying the engine, finding resources, and distinguishing routine actions from destructive cleanup.

## Token layers

| Layer | Source | Purpose |
| --- | --- | --- |
| Primitive | `lib/theme/design_tokens.dart` | Blue/slate palette, 8px spacing base, radii, control height, sidebar widths |
| Semantic | `AppColors` and the light/dark `ColorScheme` in `lib/theme/app_theme.dart` | Canvas, raised panels, borders, readable text, primary actions, status colors |
| Component | `AppTheme._components`, `PageHeader`, `DataTableShell`, `AppSidebar` | Button states, inputs, dialogs, page actions, navigation, table layout |

The design-system skill's three layers are implemented as Dart constants and Flutter themes. CSS tokens are not used because this is a native Flutter app.

## Layout

- Wide windows have a 232px sidebar grouped into Workspace and Resources, with Settings and connection details at the bottom.
- Below 1100px, navigation becomes a 76px rail. Tooltips and semantic labels preserve destination names.
- A 64px toolbar supplies page context, connection refresh, and a light/dark theme toggle.
- Pages use 28px padding. Resource headers stack actions below the title below 760px of available content width.
- Table toolbars wrap search and bulk actions. Table columns retain usable widths and scroll horizontally instead of crushing text or hiding actions.
- Dashboard sections separate the engine summary, resource counts, storage breakdown, and recent activity.

## Components and states

| Component | Default | Hover / focus | Active / selected | Disabled / loading |
| --- | --- | --- | --- | --- |
| Primary button | Solid blue, white label, 42px minimum height | Material state overlay and keyboard focus | Material pressed overlay | Material disabled colors |
| Secondary button | Bordered, surface text | Material state overlay | Material pressed overlay | Material disabled colors |
| Navigation | Muted icon and label | Ink response | Tinted primary surface, stronger label, selection semantics | Not applicable |
| Input | Raised surface, outlined border | Primary focus border | Editable content | Flutter disabled state |
| Table | Bordered panel, tinted header, divided rows | Existing row ink response | Checkbox and bulk toolbar | Loading spinner, meaningful empty state |
| Dialog | Raised surface, 16px radius | Keyboard focus through Material controls | Explicit confirmation for destructive actions | Action-specific state |

## Type and color

Keep the existing Hanken Grotesk interface and JetBrains Mono telemetry. Heading sizes are 24–32px, body 14px, secondary copy 12px. The primary palette is blue with slate neutrals; dark mode uses navy surfaces. Status labels include text as well as color.

Specialized terminal palettes remain in place; the Compose file editor follows the active surface theme. Their raw colors and some local spacing values are not yet migrated into shared tokens. Google Fonts still uses runtime fetching; an offline font bundle remains a follow-up.

## Verification

`test/widget_test.dart` checks all seven destinations in both themes at 800px and 1440px, including container search and selection. These checks use fake Docker data and perform no Docker mutations. The multi-file Compose editor is also checked at both widths, including failed-read save protection. Native platform rendering still needs manual visual QA on macOS and Windows.


Feedback uses `lib/widgets/message_dialog.dart`: scrollable message dialogs for results/errors and non-dismissible progress dialogs for active operations. Progress routes are removed by identity, so finishing one operation cannot accidentally close another dialog. Destructive actions continue to use `ConfirmDialog`. Resource-load failures also provide inline retry controls.


Status badges use compact padding and shrink to the label inside wider table cells. An outer alignment widget absorbs the column width, while the decorated pill stays close to its contents. Long labels truncate without overflowing. Compose profile controls show available profile names separately from the profiles selected for future actions.
