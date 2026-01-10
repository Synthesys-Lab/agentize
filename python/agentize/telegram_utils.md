# Telegram Utilities Interface

## External Interface

### `escape_html(text: str) -> str`

Escape special HTML characters for Telegram HTML parse mode.

**Parameters:**
- `text`: Raw text string to escape

**Returns:** HTML-safe string with `<`, `>`, and `&` escaped

**Escapes:**
- `&` -> `&amp;`
- `<` -> `&lt;`
- `>` -> `&gt;`
