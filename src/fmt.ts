import * as vscode from "vscode";
import * as childProcess from "child_process";
import { LanguageClient } from "vscode-languageclient/node";
import {
  TextDocumentIdentifier,
  DocumentFormattingRequest,
} from "vscode-languageclient/node";
import { getLanguageService, TextDocument } from "vscode-html-languageservice";

/* ============================================================================
[Input Document]
       |
       v
[Choose Formatting Function]
       |
       +-------------------+
       |                   |
       v                   v
[formatZx]           [formatZig]
       |                   |
       v                   v
[Processing Logic]   [Processing Logic]
       |                   |
       v                   v
[Output Document]   [Output Document]
       |
       v
[formatHtml]
       |
       v
[Processing Logic]
       |
       v
[Output Document]
*/
// ============================================================================

/**
 * Main entry point for formatting ZX code.
 * Orchestrates the formatting of both Zig and HTML content.
 */
export async function formatZx(
  documentText: string,
  options: vscode.FormattingOptions,
  token: vscode.CancellationToken,
  client: LanguageClient,
  originalUri: string,
  virtualZigDocumentContents: Map<string, string>,
  virtualHtmlDocumentContents: Map<string, string>,
): Promise<string> {
  // Step 1: Extract HTML and get prepared Zig code
  const htmlExtractedDoc = extractHtmls(documentText);

  // Step 2: Format the Zig code
  const formattedZigCode = await formatZig(
    htmlExtractedDoc.preparedDocumentText,
    options,
    token,
    client,
    originalUri,
    virtualZigDocumentContents,
  );

  // Step 3: Format HTML sections
  const formattedHtmlContents = new Map<string, string>();
  const htmlLanguageService = getLanguageService();

  for (const [key, htmlContent] of htmlExtractedDoc.htmlContents.entries()) {
    const formattedHtml = await formatHtml(
      htmlContent,
      key,
      options,
      token,
      client,
      originalUri,
      virtualZigDocumentContents,
      virtualHtmlDocumentContents,
      htmlLanguageService,
    );
    formattedHtmlContents.set(key, formattedHtml);
  }

  // Step 4: Merge formatted Zig code and HTML back together
  const result = patchInFormattedHtml(formattedZigCode, formattedHtmlContents);

  return result;
}

/**
 * Formats Zig code by preparing it and applying Zig formatter (ZLS or zig fmt CLI).
 */
export async function formatZig(
  preparedZigText: string,
  options: vscode.FormattingOptions,
  token: vscode.CancellationToken,
  client: LanguageClient,
  originalUri: string,
  virtualZigDocumentContents: Map<string, string>,
): Promise<string> {
  // Store the prepared Zig content in virtual document
  virtualZigDocumentContents.set(originalUri, preparedZigText);

  const zigVirtualUri = vscode.Uri.parse(
    `embedded-content-fmt-zig://zig/${encodeURIComponent(originalUri)}.zig`,
  );

  const formattingProvider = vscode.workspace
    .getConfiguration("zig")
    .get<string>("formattingProvider");

  // Try ZLS if configured; otherwise fall back to `zig fmt` CLI
  if (formattingProvider === "zls") {
    try {
      // First try formatting the virtual document (prepared document)
      let zigTextEdits = (await client.sendRequest(
        DocumentFormattingRequest.type,
        {
          textDocument: TextDocumentIdentifier.create(zigVirtualUri.toString()),
          options: {
            tabSize: options.tabSize,
            insertSpaces: options.insertSpaces,
          },
        },
        token,
      )) as vscode.TextEdit[] | null;

      // If ZLS returns null for the virtual URI, try asking it to format the real document URI
      if (!zigTextEdits) {
        try {
          zigTextEdits = (await client.sendRequest(
            DocumentFormattingRequest.type,
            {
              textDocument: TextDocumentIdentifier.create(originalUri),
              options: {
                tabSize: options.tabSize,
                insertSpaces: options.insertSpaces,
              },
            },
            token,
          )) as vscode.TextEdit[] | null;
        } catch (err) {
          console.warn("ZLS formatting on original document failed:", err);
          zigTextEdits = null;
        }
      }

      if (zigTextEdits && zigTextEdits.length > 0) {
        // Apply the edits to get formatted Zig code
        return applyTextEdits(preparedZigText, zigTextEdits);
      }
    } catch (error) {
      console.error("ZLS formatting failed:", error);
    }
  }

  // Fall back to zig fmt CLI
  return runZigFmt(preparedZigText, token);
}

/**
 * Formats HTML content, including any embedded Zig expressions within it.
 */
export async function formatHtml(
  htmlContent: string,
  htmlKey: string,
  options: vscode.FormattingOptions,
  token: vscode.CancellationToken,
  client: LanguageClient,
  originalUri: string,
  virtualZigDocumentContents: Map<string, string>,
  virtualHtmlDocumentContents: Map<string, string>,
  htmlLanguageService: ReturnType<typeof getLanguageService>,
): Promise<string> {
  // First, extract zig expressions inside this HTML block
  const zigExpressions = extractZigExprs(htmlContent);
  // segment.preparedSegmentText contains <zig:N /> placeholders instead of zig expressions

  // For each zig segment, we need to format it. Zig segments themselves may contain HTML, so
  // we must run prepareFmtDoc on each segment and format inner html, then format the zig.
  const formattedZigExpressions = new Map<string, string>();

  for (const [zigKey, zigText] of zigExpressions.exprss.entries()) {
    // Prepare inner HTML inside this zigText
    const innerPrepared = extractHtmls(zigText);

    // Format inner HTML blocks inside this zig segment
    const innerFormattedHtml = new Map<string, string>();
    for (const [innerKey, innerHtml] of innerPrepared.htmlContents.entries()) {
      const innerVirtualKey = originalUri + htmlKey + zigKey + innerKey;
      virtualHtmlDocumentContents.set(innerVirtualKey, innerHtml);

      const innerHtmlVirtualUri = vscode.Uri.parse(
        `embedded-content-fmt-html://html/${encodeURIComponent(innerVirtualKey)}.html`,
      );

      const innerVirtualHtmlDoc = TextDocument.create(
        innerHtmlVirtualUri.toString(),
        "html",
        0,
        innerHtml,
      );
      const innerHtmlTextEdits = htmlLanguageService.format(
        innerVirtualHtmlDoc,
        undefined,
        { tabSize: options.tabSize, insertSpaces: options.insertSpaces },
      );
      const innerFormatted = applyHtmlTextEdits(innerHtml, innerHtmlTextEdits);
      innerFormattedHtml.set(innerKey, innerFormatted);
    }

    // Now format the zig prepared text (with @html placeholders) via ZLS or CLI
    const formattedPreparedZig = await formatZigExprs(
      innerPrepared.preparedDocumentText,
      htmlKey + zigKey,
      options,
      token,
      client,
      originalUri,
      virtualZigDocumentContents,
    );

    // Put back inner formatted HTML into the formatted zig text
    const formattedZigWithHtml = patchInFormattedHtml(
      formattedPreparedZig,
      innerFormattedHtml,
    );

    formattedZigExpressions.set(zigKey, formattedZigWithHtml);
  }

  // Now we have formatted zig segments. Replace <zig:N /> placeholders in the segment.preparedSegmentText
  let htmlWithZigPlaceholders = zigExpressions.preparedSegmentText;

  // Store HTML content (with formatted zig segments inserted) in virtual HTML map so the HTML formatter can see it
  const virtualHtmlKey = originalUri + htmlKey;
  virtualHtmlDocumentContents.set(virtualHtmlKey, htmlWithZigPlaceholders);

  const htmlVirtualUri = vscode.Uri.parse(
    `embedded-content-fmt-html://html/${encodeURIComponent(virtualHtmlKey)}.html`,
  );

  const virtualHtmlDoc = TextDocument.create(
    htmlVirtualUri.toString(),
    "html",
    0,
    htmlWithZigPlaceholders,
  );

  const htmlTextEdits = htmlLanguageService.format(virtualHtmlDoc, undefined, {
    tabSize: options.tabSize,
    insertSpaces: options.insertSpaces,
  });

  let formattedHtml = applyHtmlTextEdits(
    htmlWithZigPlaceholders,
    htmlTextEdits,
  );

  // There may be remaining raw <zig:N /> placeholders if any; ensure formattedZigSegments are reinserted
  // When replacing, preserve the indentation of the placeholder line
  for (const [zigKey, formattedZig] of formattedZigExpressions.entries()) {
    formattedHtml = formattedHtml.replace(zigKey, (match) => {
      // Find the line containing the placeholder to get its indentation
      const lines = formattedHtml.split("\n");
      let placeholderIndent = "";

      for (const line of lines) {
        if (line.includes(zigKey)) {
          // Extract the leading whitespace from the line containing the placeholder
          const indentMatch = line.match(/^(\s*)/);
          placeholderIndent = indentMatch ? indentMatch[1] : "";
          break;
        }
      }

      // Transform the formatted Zig expression to remove extra line breaks and adjust indentation
      const transformedZig = cleanupZigExprs(
        formattedZig,
        options.tabSize,
        options.insertSpaces,
      );

      // Apply the indentation to all lines of the transformed Zig expression
      const zigLines = transformedZig.split("\n");
      const indentedZigLines = zigLines.map((line, index) => {
        // First line already has correct indentation from the placeholder position
        if (index === 0) return line;
        // Last line with closing braces - remove extra indentation and align with opening brace
        if (index === zigLines.length - 1) {
          const trimmed = line.trim();
          // If it's just closing braces, use placeholder indentation (same as first line)
          if (trimmed.match(/^}+$/)) {
            return placeholderIndent + trimmed;
          }
        }
        // Subsequent lines need the same indentation as the placeholder
        return line ? placeholderIndent + line : line;
      });

      // Ensure closing braces are on the same line (in case they got split)
      // If the last two lines are just closing braces, merge them
      if (indentedZigLines.length >= 2) {
        const lastLine = indentedZigLines[indentedZigLines.length - 1];
        const secondLastLine = indentedZigLines[indentedZigLines.length - 2];
        if (lastLine.trim() === "}" && secondLastLine.trim().endsWith("}")) {
          // Merge the closing braces using placeholder indentation (same as first line)
          const merged = secondLastLine.trimEnd().slice(0, -1) + "}}";
          indentedZigLines[indentedZigLines.length - 2] =
            placeholderIndent + merged.trim();
          indentedZigLines.pop();
        }
      }

      return indentedZigLines.join("\n");
    });
  }

  return formattedHtml;
}

// ============================================================================
// HELPER FUNCTIONS - Document preparation and transformation
// ============================================================================

type PreparedFmtDoc = {
  preparedDocumentText: string;
  htmlContents: Map<string, string>;
};

/**
 * Prepares a ZX document for formatting by extracting HTML blocks and replacing them with placeholders.
 * This allows the Zig formatter to work on the code without being confused by HTML syntax.
 */
export function extractHtmls(documentText: string): PreparedFmtDoc {
  const htmlContents = new Map<string, string>();
  let htmlIndex = 0;

  // Build a lookup of characters that are inside strings or comments so we can ignore
  // HTML-like sequences that appear inside quotes or comments (e.g. "<script>...").
  const forbidden = new Array<boolean>(documentText.length).fill(false);
  let inSingleQuote = false;
  let inDoubleQuote = false;
  let inSingleLineComment = false;
  let inMultiLineComment = false;

  for (let i = 0; i < documentText.length; i++) {
    const ch = documentText[i];
    const next = i + 1 < documentText.length ? documentText[i + 1] : "";

    // Handle comment start/end when not in a string
    if (!inSingleQuote && !inDoubleQuote) {
      if (
        !inSingleLineComment &&
        !inMultiLineComment &&
        ch === "/" &&
        next === "/"
      ) {
        inSingleLineComment = true;
        forbidden[i] = true;
        continue;
      }
      if (
        !inSingleLineComment &&
        !inMultiLineComment &&
        ch === "/" &&
        next === "*"
      ) {
        inMultiLineComment = true;
        forbidden[i] = true;
        continue;
      }
      if (inSingleLineComment && ch === "\n") {
        inSingleLineComment = false;
        forbidden[i] = true;
        continue;
      }
      if (inMultiLineComment && ch === "*" && next === "/") {
        // mark the '*' and the '/' then end the comment
        forbidden[i] = true;
        if (i + 1 < forbidden.length) forbidden[i + 1] = true;
        inMultiLineComment = false;
        i++;
        continue;
      }
    }

    // If in any comment, mark and continue
    if (inSingleLineComment || inMultiLineComment) {
      forbidden[i] = true;
      continue;
    }

    // Handle string toggles and escapes
    const isEscaped =
      i > 0 &&
      documentText[i - 1] === "\\" &&
      !(i > 1 && documentText[i - 2] === "\\");
    if (!inSingleLineComment && !inMultiLineComment) {
      if (!inSingleQuote && !inDoubleQuote && ch === '"' && !isEscaped) {
        inDoubleQuote = true;
        forbidden[i] = true;
        continue;
      } else if (inDoubleQuote && ch === '"' && !isEscaped) {
        forbidden[i] = true;
        inDoubleQuote = false;
        continue;
      }

      if (!inSingleQuote && !inDoubleQuote && ch === "'" && !isEscaped) {
        inSingleQuote = true;
        forbidden[i] = true;
        continue;
      } else if (inSingleQuote && ch === "'" && !isEscaped) {
        forbidden[i] = true;
        inSingleQuote = false;
        continue;
      }
    }

    // If inside a string, mark and continue
    if (inSingleQuote || inDoubleQuote) {
      forbidden[i] = true;
      continue;
    }
  }

  // Find all opening tags and match them with their closing tags, skipping any that lie inside strings/comments
  const openingTagRegex = /<([a-zA-Z][a-zA-Z0-9]*)[^>]*>/g;
  let match;
  const matches: Array<{
    start: number;
    end: number;
    tagName: string;
    fullMatch: string;
  }> = [];

  // First, collect all opening tags with their positions
  while ((match = openingTagRegex.exec(documentText)) !== null) {
    const start = match.index;
    // skip if this opening tag is inside a string or comment
    if (forbidden[start]) continue;

    const tagName = match[1];
    const fullMatch = match[0];

    // Find the matching closing tag, accounting for nested tags of the same type
    let depth = 1;
    let pos = match.index + fullMatch.length;
    let closingTagIndex = -1;

    while (pos < documentText.length && depth > 0) {
      // Look for opening tags of the same type
      const nextOpening = documentText.indexOf(`<${tagName}`, pos);
      // Look for closing tags
      const nextClosing = documentText.indexOf(`</${tagName}>`, pos);

      if (nextClosing === -1) {
        // No closing tag found, break
        break;
      }

      if (nextOpening !== -1 && nextOpening < nextClosing) {
        // Ensure nested opening isn't inside a string/comment
        if (!forbidden[nextOpening]) {
          depth++;
          pos = nextOpening + `<${tagName}`.length;
          // Find the end of this opening tag
          const tagEnd = documentText.indexOf(">", pos);
          if (tagEnd !== -1) {
            pos = tagEnd + 1;
          }
        } else {
          // Skip past this opening occurrence since it's inside a string/comment
          pos = nextOpening + 1;
        }
      } else {
        // Found closing tag
        if (!forbidden[nextClosing]) {
          depth--;
          if (depth === 0) {
            closingTagIndex = nextClosing + `</${tagName}>`.length;
            break;
          }
          pos = nextClosing + `</${tagName}>`.length;
        } else {
          pos = nextClosing + 1;
        }
      }
    }

    if (closingTagIndex !== -1) {
      matches.push({
        start: match.index,
        end: closingTagIndex,
        tagName: tagName,
        fullMatch: documentText.substring(match.index, closingTagIndex),
      });
    }
  }

  // Filter out nested matches - only keep outermost HTML blocks
  const filteredMatches: Array<{
    start: number;
    end: number;
    tagName: string;
    fullMatch: string;
  }> = [];
  for (let i = 0; i < matches.length; i++) {
    const current = matches[i];
    let isNested = false;

    // Check if this match is nested inside any other match
    for (let j = 0; j < matches.length; j++) {
      if (i !== j) {
        const other = matches[j];
        if (current.start > other.start && current.end < other.end) {
          isNested = true;
          break;
        }
      }
    }

    if (!isNested) {
      filteredMatches.push(current);
    }
  }

  // Sort matches by start position to assign indices in order
  filteredMatches.sort((a, b) => a.start - b.start);

  // First, assign indices and store mappings
  const matchToIndex = new Map<(typeof filteredMatches)[0], number>();
  filteredMatches.forEach((match, index) => {
    matchToIndex.set(match, index);
    htmlContents.set(`@html(${index})`, match.fullMatch);
  });

  // Replace HTML blocks with placeholders (from end to start to avoid position shifts)
  let result = documentText;
  for (let i = filteredMatches.length - 1; i >= 0; i--) {
    const match = filteredMatches[i];
    const index = matchToIndex.get(match)!;
    const key = `@html(${index})`;

    // Find the start of the whitespace before the HTML block
    let replaceStart = match.start;
    while (replaceStart > 0 && /\s/.test(result[replaceStart - 1])) {
      replaceStart--;
    }

    // Find the end of the whitespace after the HTML block
    let replaceEnd = match.end;
    while (replaceEnd < result.length && /\s/.test(result[replaceEnd])) {
      replaceEnd++;
    }

    // Check if we're inside a return statement with parentheses
    const beforeText = result.substring(
      Math.max(0, replaceStart - 20),
      replaceStart,
    );
    const afterText = result.substring(
      match.end,
      Math.min(result.length, match.end + 20),
    );

    // If we have "return (" before and ")" after, collapse to single line
    if (
      beforeText.trimEnd().endsWith("return (") &&
      afterText.trimStart().startsWith(")")
    ) {
      // Collapse to single line: remove newlines and extra spaces, no space around key
      const before = result.substring(0, replaceStart).trimEnd();
      const after = result.substring(replaceEnd).trimStart();
      result = before + key + after;
    } else {
      // Keep original whitespace
      result =
        result.substring(0, replaceStart) + key + result.substring(replaceEnd);
    }
  }

  return { preparedDocumentText: result, htmlContents: htmlContents };
}

/**
 * Replaces HTML placeholders in formatted Zig code with the actual formatted HTML content.
 */
export function patchInFormattedHtml(
  formattedText: string,
  htmlContents: Map<string, string>,
): string {
  let result = formattedText;

  for (const [key, htmlContent] of htmlContents.entries()) {
    let replacement = htmlContent;
    const isMultiLine = htmlContent.includes("\n");
    if (isMultiLine) {
      const lines = result.split("\n");
      const keyLineIndex = lines.findIndex((line) => line.includes(key));
      const keyLine = keyLineIndex >= 0 ? lines[keyLineIndex] : "";
      const currentKeyIndentation = keyLine.match(/^\s*/)?.[0] || "";

      // Check if the key is inside a for loop by looking backwards from the key line
      let isInsideForLoop = false;
      if (keyLineIndex >= 0) {
        // Look backwards from the key line to find if we're inside a for loop
        for (let i = keyLineIndex; i >= 0; i--) {
          const line = lines[i];
          // Check if this line contains a for loop opening
          if (/\bfor\s*\(/.test(line)) {
            // Find the opening brace after the for statement
            let openingBraceLine = -1;
            let openingBracePos = -1;
            for (let j = i; j <= keyLineIndex; j++) {
              const currentLine = lines[j];
              const braceIndex = currentLine.indexOf('{');
              if (braceIndex !== -1) {
                openingBraceLine = j;
                openingBracePos = braceIndex;
                break;
              }
            }
            
            if (openingBraceLine === -1) {
              // No opening brace found, not inside for loop
              break;
            }
            
            // Count braces from the opening brace to the key line
            let braceCount = 1; // We start with the opening brace
            for (let j = openingBraceLine; j <= keyLineIndex; j++) {
              const currentLine = lines[j];
              const startPos = j === openingBraceLine ? openingBracePos + 1 : 0;
              for (let k = startPos; k < currentLine.length; k++) {
                const char = currentLine[k];
                if (char === '{') {
                  braceCount++;
                } else if (char === '}') {
                  braceCount--;
                  if (braceCount === 0) {
                    // We've closed the opening brace before reaching the key
                    break;
                  }
                }
              }
              if (braceCount === 0) {
                break;
              }
            }
            
            // If we're still inside braces (braceCount > 0), we're in a for loop
            if (braceCount > 0) {
              isInsideForLoop = true;
            }
            break;
          }
        }
      }

      if (isInsideForLoop) {
        // For for loops, use single indentation level and no extra newlines
        const indentedHtmlContent = htmlContent
          .split("\n")
          .map((line) => {
            return currentKeyIndentation + line;
          })
          .join("\n");

        replacement = indentedHtmlContent;
      } else {
        // For other cases (if/else), use double indentation and add newlines
        const indentedHtmlContent = htmlContent
          .split("\n")
          .map((line) => {
            return currentKeyIndentation.repeat(2) + line;
          })
          .join("\n");

        replacement = `\n${indentedHtmlContent}\n${currentKeyIndentation}`;
      }
    }

    result = result.replace(key, replacement);
  }

  return result;
}

type PreparedFmtSegment = {
  exprss: Map<string, string>;
  preparedSegmentText: string;
};

/**
 * Prepares an HTML segment for formatting by extracting Zig expressions (for/if/switch) and replacing them with placeholders.
 */
export function extractZigExprs(documentText: string): PreparedFmtSegment {
  const zigSegments = new Map<string, string>();
  let preparedSegmentText = documentText;

  // Find all zig expressions: { for (...) } or { if (...) } or { switch (...) }
  // Allow optional whitespace/newlines right after the opening '{'.
  // These can include capture variables like { for (items) |item| (...) }
  const zigExpressionRegex = /{\s*(for|if|switch)\s*\(/g;
  let match;
  const matches: Array<{ start: number; end: number; fullMatch: string }> = [];

  // First, collect all opening expressions with their positions
  while ((match = zigExpressionRegex.exec(documentText)) !== null) {
    const keyword = match[1];
    const start = match.index;
    let pos = match.index + match[0].length; // Position after "{for (" or "{if (" or "{switch ("

    // Find the matching closing parenthesis for the condition
    let parenDepth = 1;
    while (pos < documentText.length && parenDepth > 0) {
      if (documentText[pos] === "(") parenDepth++;
      else if (documentText[pos] === ")") parenDepth--;
      pos++;
    }

    if (parenDepth !== 0) continue; // No matching closing paren found

    // Skip whitespace after the closing paren
    while (pos < documentText.length && /\s/.test(documentText[pos])) {
      pos++;
    }

    // Check for optional capture variable |variable|
    if (documentText[pos] === "|") {
      pos++; // Skip opening |
      // Find closing |
      const captureEnd = documentText.indexOf("|", pos);
      if (captureEnd !== -1) {
        pos = captureEnd + 1;
        // Skip whitespace after capture variable
        while (pos < documentText.length && /\s/.test(documentText[pos])) {
          pos++;
        }
      }
    }

    // Now find the body and matching closing brace
    // The body is wrapped in parentheses, then the whole expression ends with }
    let braceDepth = 1; // We're already inside one opening brace

    // Find the body which is wrapped in parentheses
    if (documentText[pos] === "(") {
      // Find matching closing paren for the body
      let bodyParenDepth = 1;
      pos++; // Skip opening paren
      while (pos < documentText.length && bodyParenDepth > 0) {
        const char = documentText[pos];
        if (char === "(") {
          bodyParenDepth++;
        } else if (char === ")") {
          bodyParenDepth--;
        } else if (char === "{") {
          braceDepth++; // Track nested braces inside body
        } else if (char === "}") {
          braceDepth--; // Track nested braces inside body
        }
        pos++;
      }
    }

    // Now find the closing brace for the entire expression
    while (pos < documentText.length && braceDepth > 0) {
      const char = documentText[pos];
      if (char === "{") {
        braceDepth++;
      } else if (char === "}") {
        braceDepth--;
      }
      pos++;
    }

    if (braceDepth === 0) {
      // Found the matching closing brace
      const end = pos;
      const fullMatch = documentText.substring(start, end);
      matches.push({ start, end, fullMatch });
    }
  }

  // Replace matches from end to start to avoid position shifts
  for (let i = matches.length - 1; i >= 0; i--) {
    const match = matches[i];
    const index = zigSegments.size;
    const key = `<zig:${index} />`;

    zigSegments.set(key, match.fullMatch);
    preparedSegmentText =
      preparedSegmentText.substring(0, match.start) +
      key +
      preparedSegmentText.substring(match.end);
  }

  return { exprss: zigSegments, preparedSegmentText };
}

/**
 * Transforms formatted Zig code to remove extra line breaks and adjust indentation.
 * Merges opening { with the next line and closing } with the previous line,
 * then removes one level of indentation from middle lines.
 */
export function cleanupZigExprs(
  formattedZig: string,
  tabSize: number = 4,
  insertSpaces: boolean = true,
): string {
  let zigLines = formattedZig.split("\n");

  // Remove line break after opening curly: merge { with next line if first line is just {
  if (zigLines.length > 1 && zigLines[0].trim() === "{") {
    const secondLine = zigLines[1];
    // Merge opening brace with the next line
    zigLines[0] = "{" + secondLine.trimStart();
    zigLines.splice(1, 1);
  }

  // Remove line break before closing curly: merge } with previous line if last line is just }
  // Handle consecutive closing braces by merging them together
  while (zigLines.length > 1 && zigLines[zigLines.length - 1].trim() === "}") {
    const lastIndex = zigLines.length - 1;
    const prevLine = zigLines[lastIndex - 1];
    const prevLineTrimmed = prevLine.trimEnd();

    // If previous line ends with }, merge into }} (preserve indentation)
    if (prevLineTrimmed.endsWith("}")) {
      // Get the indentation from the previous line
      const indent = prevLine.slice(
        0,
        prevLine.length - prevLineTrimmed.length,
      );
      // Replace the trailing } with }}
      zigLines[lastIndex - 1] = indent + prevLineTrimmed.slice(0, -1) + "}}";
    } else {
      // Otherwise, just append } to the previous line
      zigLines[lastIndex - 1] = prevLine.trimEnd() + "}";
    }
    zigLines.pop();
  }

  // Apply indentNegate to remove one level of indentation from lines 1 to lineCount - 1
  // This includes the last line (which may have been merged with closing brace)
  if (zigLines.length > 1) {
    zigLines = indentNegate(
      zigLines,
      1,
      zigLines.length - 1,
      1,
      tabSize,
      insertSpaces,
    );
  }

  // Join lines and remove any trailing newline
  return zigLines.join("\n").replace(/\n+$/, "");
}

/**
 * Adds semicolons after @html(n) patterns inside control flow statements to make valid Zig syntax.
 * This is needed because inside if/else/for/while blocks, expressions need semicolons.
 * Note: switch statements do NOT require semicolons, so they are excluded.
 */
function addSemicolonsToHtmlPlaceholders(text: string): string {
  // Match @html(n) or (@html(n)) patterns
  const htmlPattern = /(@html\(\d+\)|\(@html\(\d+\)\))/g;
  const matches: Array<{ match: string; index: number }> = [];
  
  // Collect all matches with their positions
  let match;
  while ((match = htmlPattern.exec(text)) !== null) {
    matches.push({ match: match[0], index: match.index });
  }
  
  // Process matches from end to start to avoid position shifts
  let result = text;
  for (let i = matches.length - 1; i >= 0; i--) {
    const { match: htmlMatch, index } = matches[i];
    
    // Check if this is already followed by a semicolon
    const afterMatch = result.slice(index + htmlMatch.length);
    const trimmedAfter = afterMatch.trimStart();
    
    // If already has semicolon, skip
    if (trimmedAfter.startsWith(';')) {
      continue;
    }
    
    // Check if we're inside a control flow block by looking backwards for if/else/for/while
    // and checking if we're inside braces
    // Note: switch statements are excluded as they don't require semicolons
    const beforeMatch = result.slice(0, index);
    
    // Find all control flow keywords before this position
    const controlFlowMatches: Array<{ keyword: string; index: number }> = [];
    
    // Handle keywords with parentheses: if, for, while
    for (const keyword of ['if', 'for', 'while']) {
      const regex = new RegExp(`\\b${keyword}\\s*\\(`, 'g');
      let m;
      while ((m = regex.exec(beforeMatch)) !== null) {
        controlFlowMatches.push({ keyword, index: m.index });
      }
    }
    
    // Also check for 'else' (which doesn't have parentheses)
    const elseRegex = /\belse\s*{/g;
    let elseMatch;
    while ((elseMatch = elseRegex.exec(beforeMatch)) !== null) {
      controlFlowMatches.push({ keyword: 'else', index: elseMatch.index });
    }
    
    // Check for switch statements (to exclude them)
    const switchRegex = /\bswitch\s*\(/g;
    let switchMatch;
    while ((switchMatch = switchRegex.exec(beforeMatch)) !== null) {
      controlFlowMatches.push({ keyword: 'switch', index: switchMatch.index });
    }
    
    // Find the closest control flow keyword
    if (controlFlowMatches.length === 0) {
      continue;
    }
    
    // Sort by index descending to get the closest (last) one
    controlFlowMatches.sort((a, b) => b.index - a.index);
    const closestControlFlow = controlFlowMatches[0];
    
    // If the closest control flow is a switch, skip adding semicolon
    if (closestControlFlow.keyword === 'switch') {
      continue;
    }
    
    const lastControlFlowPos = closestControlFlow.index;
    
    // Check if we're inside braces after the control flow keyword
    // Find the opening brace of the control flow block and count braces to our position
    const afterControlFlow = beforeMatch.slice(lastControlFlowPos);
    let braceCount = 0;
    let foundOpeningBrace = false;
    let openingBracePos = -1;
    
    // Find the opening brace after the control flow keyword
    for (let j = 0; j < afterControlFlow.length; j++) {
      const char = afterControlFlow[j];
      if (char === '{') {
        openingBracePos = j;
        foundOpeningBrace = true;
        braceCount = 1;
        break;
      }
    }
    
    if (!foundOpeningBrace) {
      continue;
    }
    
    // Count braces from the opening brace to our position
    for (let k = openingBracePos + 1; k < afterControlFlow.length; k++) {
      const char = afterControlFlow[k];
      if (char === '{') {
        braceCount++;
      } else if (char === '}') {
        braceCount--;
        if (braceCount === 0) {
          // We've closed the opening brace before reaching our position
          break;
        }
      }
    }
    
    // If we're still inside the opening brace (braceCount > 0), add semicolon
    if (braceCount > 0) {
      result = result.slice(0, index + htmlMatch.length) + ';' + result.slice(index + htmlMatch.length);
    }
  }
  
  return result;
}

/**
 * Removes semicolons that were added after @html(n) patterns.
 * This reverses the effect of addSemicolonsToHtmlPlaceholders.
 */
function removeSemicolonsFromHtmlPlaceholders(text: string): string {
  // Remove semicolons that immediately follow @html(n) or (@html(n))
  return text.replace(/(@html\(\d+\)|\(@html\(\d+\)\));/g, '$1');
}

/**
 * Formats a prepared Zig text segment (which may still contain @html(...) placeholders).
 * Tries ZLS (virtual URI), then falls back to `zig fmt --stdin`.
 */
async function formatZigExprs(
  preparedZigText: string,
  segmentId: string,
  options: vscode.FormattingOptions,
  token: vscode.CancellationToken,
  client: LanguageClient,
  originalUri: string,
  virtualZigDocumentContents: Map<string, string>,
): Promise<string> {
  // store in virtual map so virtual content provider can return it
  const virtualKey = originalUri + segmentId;

  // Add semicolons after @html(n) patterns inside control flow statements to make valid Zig
  const textWithSemicolons = addSemicolonsToHtmlPlaceholders(preparedZigText);

  // Prefix to make the prepared segment a valid Zig snippet for the formatter.
  // Keep this in sync with the slice length used later when removing the prefix.
  const validZigDoc = "test " + textWithSemicolons;

  virtualZigDocumentContents.set(virtualKey, validZigDoc);
  const virtUri = vscode.Uri.parse(
    `embedded-content-fmt-zig://zig/${encodeURIComponent(virtualKey)}.zig`,
  );

  try {
    let edits = (await client.sendRequest(DocumentFormattingRequest.type, {
      textDocument: TextDocumentIdentifier.create(virtUri.toString()),
      options: {
        tabSize: options.tabSize,
        insertSpaces: options.insertSpaces,
      },
    })) as vscode.TextEdit[] | null;

    if (!edits) {
      // Try asking zls to format the real document as a last attempt (some servers ignore non-file schemes)
      try {
        edits = (await client.sendRequest(DocumentFormattingRequest.type, {
          textDocument: TextDocumentIdentifier.create(originalUri),
          options: {
            tabSize: options.tabSize,
            insertSpaces: options.insertSpaces,
          },
        })) as vscode.TextEdit[] | null;
      } catch (e) {
        edits = null;
      }
    }

    if (edits && edits.length > 0) {
      const formatted = applyTextEdits(validZigDoc, edits);
      const withoutPrefix = formatted.slice("test ".length);
      // Remove semicolons we added before formatting
      return removeSemicolonsFromHtmlPlaceholders(withoutPrefix);
    }
  } catch (err) {
    console.warn(
      "ZLS per-segment formatting failed, falling back to zig fmt --stdin",
      err,
    );
  }

  // Fallback to CLI
  const formattedEdits = await runZigFmt(validZigDoc, token);
  const withoutPrefix = formattedEdits.slice("test ".length);
  // Remove semicolons we added before formatting
  return removeSemicolonsFromHtmlPlaceholders(withoutPrefix);
}

/**
 * Runs `zig fmt --stdin` on prepared text. Returns formatted text or original on failure.
 */
export async function runZigFmt(
  text: string,
  token: vscode.CancellationToken,
): Promise<string> {
  return new Promise<string>((resolve) => {
    try {
      const child = childProcess.spawn("zig", ["fmt", "--stdin"], {
        stdio: ["pipe", "pipe", "pipe"],
      });

      let stdout = "";
      let stderr = "";

      child.stdout.on("data", (chunk) => {
        stdout += chunk.toString();
      });
      child.stderr.on("data", (chunk) => {
        stderr += chunk.toString();
      });

      child.on("error", (err) => {
        console.error("zig fmt spawn error:", err);
        resolve(text);
      });

      child.on("close", (code) => {
        if (code === 0) {
          resolve(stdout);
        } else {
          console.warn("zig fmt exited with code", code, "stderr:", stderr);
          resolve(text);
        }
      });

      // Write input and end
      child.stdin.end(text);

      // Cancellation support
      token.onCancellationRequested(() => {
        try {
          child.kill();
        } catch (e) {
          // ignore
        }
        resolve(text);
      });
    } catch (err) {
      console.error("runZigFmtOnPrepared error:", err);
      resolve(text);
    }
  });
}

/**
 * Removes indentation from specific lines in an array of lines.
 * Used to adjust indentation after merging braces in Zig expressions.
 */
function indentNegate(
  lines: string[],
  startLine: number,
  endLine: number,
  negateLevel: number,
  tabSize: number,
  insertSpaces: boolean,
): string[] {
  const indentSize = insertSpaces ? tabSize : 1;
  const indentToRemove = " ".repeat(indentSize * negateLevel);

  return lines.map((line, index) => {
    if (index >= startLine && index <= endLine) {
      // Remove the specified level of indentation
      if (line.startsWith(indentToRemove)) {
        return line.slice(indentToRemove.length);
      }
      // If using tabs, try removing tabs
      if (!insertSpaces && line.startsWith("\t")) {
        return line.slice(negateLevel);
      }
    }
    return line;
  });
}

/**
 * Applies text edits to a string, handling both single-line and multi-line edits.
 * Edits are sorted in reverse order to apply from end to start.
 */
export function applyTextEdits(text: string, edits: vscode.TextEdit[]): string {
  const lines = text.split("\n");

  // Sort edits in reverse order to apply from end to start
  const sortedEdits = [...edits].sort((a, b) => {
    const lineDiff = b.range.start.line - a.range.start.line;
    if (lineDiff !== 0) return lineDiff;
    return b.range.start.character - a.range.start.character;
  });

  for (const edit of sortedEdits) {
    const startLine = edit.range.start.line;
    const startChar = edit.range.start.character;
    const endLine = edit.range.end.line;
    const endChar = edit.range.end.character;

    if (startLine === endLine) {
      // Single line edit
      const line = lines[startLine];
      lines[startLine] =
        line.slice(0, startChar) + edit.newText + line.slice(endChar);
    } else {
      // Multi-line edit
      const firstLine = lines[startLine].slice(0, startChar);
      const lastLine = lines[endLine].slice(endChar);
      const newLines = edit.newText.split("\n");

      // Replace the affected lines
      lines.splice(startLine, endLine - startLine + 1, firstLine + newLines[0]);

      // Insert remaining new lines
      for (let i = 1; i < newLines.length; i++) {
        lines.splice(startLine + i, 0, newLines[i]);
      }

      // Append the last line content
      if (newLines.length > 0) {
        lines[startLine + newLines.length - 1] += lastLine;
      }
    }
  }

  return lines.join("\n");
}

/**
 * Applies HTML text edits to a string, handling both single-line and multi-line edits.
 * Similar to applyTextEdits but works with HTML-specific edit format.
 */
export function applyHtmlTextEdits(
  text: string,
  edits: Array<{ range: any; newText: string }>,
): string {
  if (!edits || edits.length === 0) return text;

  const lines = text.split("\n");

  // Sort edits in reverse order
  const sortedEdits = [...edits].sort((a, b) => {
    const lineDiff = b.range.start.line - a.range.start.line;
    if (lineDiff !== 0) return lineDiff;
    return b.range.start.character - a.range.start.character;
  });

  for (const edit of sortedEdits) {
    const startLine = edit.range.start.line;
    const startChar = edit.range.start.character;
    const endLine = edit.range.end.line;
    const endChar = edit.range.end.character;

    if (startLine === endLine) {
      const line = lines[startLine];
      lines[startLine] =
        line.slice(0, startChar) + edit.newText + line.slice(endChar);
    } else {
      const firstLine = lines[startLine].slice(0, startChar);
      const lastLine = lines[endLine].slice(endChar);
      const newLines = edit.newText.split("\n");

      lines.splice(startLine, endLine - startLine + 1, firstLine + newLines[0]);

      for (let i = 1; i < newLines.length; i++) {
        lines.splice(startLine + i, 0, newLines[i]);
      }

      if (newLines.length > 0) {
        lines[startLine + newLines.length - 1] += lastLine;
      }
    }
  }

  return lines.join("\n");
}

