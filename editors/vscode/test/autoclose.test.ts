// import { test, expect, describe } from "bun:test";
// import { shouldAutoCloseTag } from "../src/autocomplete/htmlAutocomplete";

// describe("auto-close helper", () => {
//   test("simple div", () => {
//     const text = "<div>";
//     expect(shouldAutoCloseTag(text)).toBe("div");
//   });

//   test("void tag br", () => {
//     const text = "<br>";
//     expect(shouldAutoCloseTag(text)).toBe(null);
//   });

//   test("self-closing img", () => {
//     const text = '<img src="x" />';
//     expect(shouldAutoCloseTag(text)).toBe(null);
//   });

//   test("attribute with > inside quotes", () => {
//     const text = '<div title="a>b">';
//     expect(shouldAutoCloseTag(text)).toBe(null);
//   });

//   test("closing tag typed (no auto)", () => {
//     const text = "</div>";
//     expect(shouldAutoCloseTag(text)).toBe(null);
//   });
// });
