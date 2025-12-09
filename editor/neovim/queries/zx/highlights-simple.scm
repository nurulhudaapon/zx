;; highlights.scm - Simplified syntax highlighting for ZX files
;; This version doesn't rely on Zig inheritance to avoid query assertion errors

;; ============================================================================
;; ZX-Specific Elements
;; ============================================================================

;; HTML/ZX Tags
"<" @tag.delimiter
">" @tag.delimiter
"</" @tag.delimiter
"/>" @tag.delimiter
"<>" @tag.delimiter
"</>" @tag.delimiter

;; Tag names
(zx_tag_name) @tag

;; ============================================================================
;; Attributes
;; ============================================================================

;; Builtin attributes (@allocator, @rendering, etc.)
(zx_builtin_name) @function.builtin

;; Regular HTML attributes
(zx_attribute_name) @property

;; Assignment
"=" @operator

;; ============================================================================
;; Attribute Values & Content
;; ============================================================================

;; String literals
(zx_string_literal) @string

;; Expression blocks
"{" @punctuation.bracket
"}" @punctuation.bracket

;; Text content
(zx_text) @none

;; ============================================================================
;; Special ZX Features
;; ============================================================================

;; Keywords
"const" @keyword
"@jsImport" @function.builtin

;; Punctuation
"(" @punctuation.bracket
")" @punctuation.bracket
";" @punctuation.delimiter

;; ============================================================================
;; Error Handling
;; ============================================================================

(ERROR) @error



