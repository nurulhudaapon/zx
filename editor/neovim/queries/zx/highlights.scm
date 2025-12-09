;; highlights.scm - Syntax highlighting for ZX files
;; Inherits from Zig and adds ZX-specific highlighting

;; ============================================================================
;; IMPORTANT: This file works with tree-sitter-zig grammar
;; The ZX grammar extends Zig, so Zig highlighting is automatically inherited
;; We only need to define ZX-specific highlighting here
;; ============================================================================

;; ============================================================================
;; ZX-Specific Elements
;; ============================================================================

;; HTML/ZX Tags - Delimiters
"<" @tag.delimiter
">" @tag.delimiter
"</" @tag.delimiter
"/>" @tag.delimiter
"<>" @tag.delimiter
"</>" @tag.delimiter

;; Tag names - distinguish components (PascalCase) from HTML tags
(zx_tag_name) @tag.builtin
  (#match? @tag.builtin "^[a-z][a-zA-Z0-9_]*$")

(zx_tag_name) @type
  (#match? @type "^[A-Z][a-zA-Z0-9_]*$")

;; ============================================================================
;; Attributes
;; ============================================================================

;; Builtin attributes (@allocator, @rendering, @onClick, etc.)
(zx_builtin_name) @function.builtin

;; Regular HTML attributes
(zx_attribute_name) @property

;; Common HTML attributes with special highlighting
((zx_attribute_name) @keyword.special
  (#match? @keyword.special "^(class|id|style|href|src|alt|title|type|name|value|placeholder|disabled|readonly|required|checked|selected)$"))

;; Assignment in attributes
(zx_attribute
  "=" @operator)

;; ============================================================================
;; Attribute Values & Content
;; ============================================================================

;; String literals in attributes
(zx_string_literal) @string

;; Expression blocks - just highlight the braces, content is handled by injection
(zx_expression_block
  "{" @punctuation.bracket
  "}" @punctuation.bracket)

;; Text content inside HTML elements
(zx_text) @none

;; ============================================================================
;; Special ZX Features
;; ============================================================================

;; @jsImport declarations
(zx_js_import
  "const" @keyword
  (identifier) @variable
  "=" @operator
  "@jsImport" @function.builtin
  "(" @punctuation.bracket
  (string) @string.special
  ")" @punctuation.bracket
  ";" @punctuation.delimiter)

;; ============================================================================
;; Error Handling
;; ============================================================================

(ERROR) @error
