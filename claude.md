# PopClip Extension Development Notes

Key findings and best practices for developing PopClip extensions.

## JavaScript Module Format

### .js Files (JavaScript)
- **MUST use CommonJS syntax**: `module.exports = ...`
- **CANNOT use ES6 modules**: No `export default`, `export const`, or `import`
- No build process required - loaded directly by PopClip
- Example: `module.exports = async (input, options, context) => { ... }`

### .ts Files (TypeScript)
- **Can use ES6 syntax**: `export default`, `export const`, `import`
- Automatically transpiled by PopClip using sucrase (no build required)
- Recommended for modern syntax and type safety
- Example: `export default async (input: Input, options?: Options) => { ... }`

## Action Function Signature
- Takes three parameters: `input`, `options`, `context`
- Can be async and use await
- Returns: `string | null | undefined | Promise<string | null | undefined>`
- Return value is passed to "after" step (e.g., "paste-result")

## Config.json Fields

### Module vs Actions
- **`module`**: Points to a .js or .ts file that exports the entire extension definition
- **`javascript`**: Inline JavaScript code for a single action
- **`javascript file`**: Path to a .js file for a single action
- **Cannot mix**: If using `module`, it provides ALL actions - can't add regular actions

### Static-only Properties
These can ONLY be in Config.json, never overridden by module:
- `identifier`
- `popclipVersion`
- `macosVersion`
- `entitlements`

### Options Field
- Used to define user-configurable settings for the extension
- **Must be omitted if not needed** - don't include empty array `"options": []`
- If present, should contain option definition objects
- Example: `"options": [{"identifier": "domain", "type": "multiple", "label": "Service", "values": ["is.gd", "v.gd"]}]`

## Conditional Display

### Requirements Array
- `text` - Non-empty text selection
- `url` - Exactly one HTTP(S) URL
- `urls` - One or more HTTP(S) URLs
- `email` - Email address
- `path` - File path
- Prefix with `!` to negate: `["!url"]`

### Regex Pattern
- Use `regex` field to match specific patterns
- Default pattern: `(?s)^.{1,}$` (matches any text including multiline)
- For multiline patterns, use `(?s)` flag at start
- Processing order: Requirements filter → Regex match → Action receives matched text
- Original text always available via `input.text`

## Icons
- PNG format: 256x256px minimum, black on transparent
- Inline SVG: `"icon": "data:image/svg+xml,..."`
- Iconify reference: `"icon": "iconify:mdi:link-variant-plus"`
- Icon names: Check [Iconify](https://icon-sets.iconify.design/) for available icons
- Note: Not all Iconify icons may work - test to ensure they display correctly

## TypeScript Setup (Optional)
```bash
npm install -D typescript @popclip/types
```

Create `tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"]
  }
}
```

## Common Pitfalls
- Using ES6 syntax in .js files (use .ts instead or switch to CommonJS)
- Forgetting `(?s)` flag for multiline regex patterns
- Trying to override static properties from module code
- Not handling null/undefined returns in action functions
- Including empty `options` array in Config.json (omit the field entirely if no options needed)
- Using incorrect Iconify icon names (e.g., `mdi:link-plus` may not exist, use `mdi:link-variant-plus` instead)

## Resources
- [Official PopClip Extensions](https://github.com/pilotmoon/PopClip-Extensions)
- [Module Documentation](https://www.popclip.app/dev/js-modules)
- [JavaScript Actions](https://www.popclip.app/dev/js-actions)
- [TypeScript Types](https://pilotmoon.github.io/popclip-types/)
- [Config Reference](https://www.popclip.app/dev/config)
