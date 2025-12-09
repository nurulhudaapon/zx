;; injections.scm - Language injections for ZX files
;; This enables proper highlighting of embedded languages

;; Inject Zig syntax into expression blocks
((zx_expression_block
  (expression) @injection.content)
  (#set! injection.language "zig")
  (#set! injection.include-children))

;; Inject CSS into style attributes
((zx_regular_attribute
  (zx_attribute_name) @_attr
  (zx_attribute_value
    (zx_string_literal) @injection.content))
  (#eq? @_attr "style")
  (#set! injection.language "css"))
