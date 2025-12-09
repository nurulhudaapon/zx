;; indents.scm - Simplified indentation for ZX files

[
  (zx_element)
  (zx_fragment)
] @indent.begin

(zx_element
  "</" @indent.dedent)

(zx_fragment
  "</>" @indent.dedent)


