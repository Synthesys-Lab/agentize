# styles.css

Styles for the Settings UI layout, form fields, and YAML previews.

## External Interface

### Layout Classes
- `.settings-root`: main layout container for the settings panel.
- `.settings-shell`: width-constrained column layout for sections.
- `.settings-header`: header stack with title, subtitle, and status line.
- `.settings-section`: card-style container for each settings scope.
- `.settings-section-header`: top row with titles and scope tags.

### Form + Status Classes
- `.settings-summary`: summary line for the currently configured backend.
- `.settings-field-grid`: grid layout for provider/model inputs.
- `.settings-input`, `.settings-select`: input styling for backend editing.
- `.settings-actions`: row for save button + inline status.
- `.settings-inline-status`: save feedback text with success/error modifiers.
- `.settings-note`: small helper text describing where values are written.

### Content Preview Classes
- `.settings-code`: YAML preview block.
- `.settings-code.is-empty`: empty-state styling for missing content.

## Internal Helpers

No internal helpers; this stylesheet only defines static presentation rules.
