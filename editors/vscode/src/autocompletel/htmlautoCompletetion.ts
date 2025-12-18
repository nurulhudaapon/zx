import * as vscode from "vscode";
import {
  getLanguageService,
  TextDocument as HTMLTextDocument,
} from "vscode-html-languageservice";

const htmlService = getLanguageService({});

export function registerHtmlAutoCompletion(
  ctx: vscode.ExtensionContext | vscode.Disposable,
  languageId: string,
) {
  let applying = false;

  const isInsideReturn = (doc: vscode.TextDocument, pos: vscode.Position) => {
    const txt = doc.getText();
    const offset = doc.offsetAt(pos);
    const before = txt.slice(0, offset);
    const retIdx = before.lastIndexOf("return");
    if (retIdx === -1) return false;
    const afterRetChar = txt[retIdx + 6] || "";
    if (/[\w$]/.test(afterRetChar)) return false;
    const afterReturn = txt.slice(retIdx);
    const openRel = afterReturn.indexOf("(");
    if (openRel === -1) return false;
    const absOpen = retIdx + openRel;
    if (absOpen > offset) return false;
    let depth = 0;
    for (let i = absOpen; i < txt.length; i++) {
      const ch = txt[i];
      if (ch === "(") depth++;
      else if (ch === ")") {
        depth--;
        if (depth === 0) return offset <= i;
      }
    }
    return true;
  };

  const complete = async (doc: vscode.TextDocument, pos: vscode.Position) => {
    if (!isInsideReturn(doc, pos)) return null;
    const html = HTMLTextDocument.create(
      doc.uri.toString(),
      "html",
      doc.version,
      doc.getText(),
    );
    const list = htmlService.doComplete(
      html,
      { line: pos.line, character: pos.character },
      htmlService.parseHTMLDocument(html),
    );
    if (!list) return null;
    return new vscode.CompletionList(
      (list.items as any[]).map((it: any) => {
        const label = typeof it.label === "string" ? it.label : it.label.label;
        const insert = (() => {
          let t = it.insertText ?? label;
          if (typeof t === "string") t = t.replace(/^</, "");
          const m = typeof t === "string" && t.match(/^([\w:-]+)/);
          return m ? m[1] : t;
        })();
        const item = new vscode.CompletionItem(
          label,
          vscode.CompletionItemKind.Property,
        );
        item.insertText = insert;
        if (it.detail) item.detail = it.detail;
        if (it.documentation)
          item.documentation =
            typeof it.documentation === "string"
              ? it.documentation
              : it.documentation.value;
        return item;
      }),
      false,
    );
  };

  const onType = async (
    doc: vscode.TextDocument,
    pos: vscode.Position,
    ch: string,
  ) => {
    if (doc.languageId !== languageId || ch !== ">") return [];
    if (
      !vscode.workspace
        .getConfiguration("zx")
        .get<boolean>("autoCloseTags", true)
    )
      return [];
    if (!isInsideReturn(doc, pos)) return [];
    const html = HTMLTextDocument.create(
      doc.uri.toString(),
      "html",
      doc.version,
      doc.getText(),
    );
    const insert = htmlService.doTagComplete(
      html,
      { line: pos.line, character: pos.character },
      htmlService.parseHTMLDocument(html),
    );
    if (!insert) return [];
    if (insert.includes("$")) {
      const ed = vscode.window.activeTextEditor;
      if (ed && ed.document.uri.toString() === doc.uri.toString()) {
        applying = true;
        await ed.insertSnippet(new vscode.SnippetString(insert), pos);
        applying = false;
      }
      return [];
    }
    return [vscode.TextEdit.insert(pos, insert)];
  };

  const completionProvider: vscode.CompletionItemProvider = {
    provideCompletionItems: (document, position) =>
      complete(document, position),
  };
  const onTypeProvider: vscode.OnTypeFormattingEditProvider = {
    provideOnTypeFormattingEdits: (document, position, ch) =>
      onType(document, position, ch),
  };

  const subs: vscode.Disposable[] = [
    vscode.languages.registerCompletionItemProvider(
      { language: languageId },
      completionProvider,
      "<",
    ),
    vscode.languages.registerOnTypeFormattingEditProvider(
      { language: languageId },
      onTypeProvider,
      ">",
    ),
  ];

  const listener = vscode.workspace.onDidChangeTextDocument(async (e) => {
    if (
      applying ||
      e.document.languageId !== languageId ||
      e.contentChanges.length !== 1
    )
      return;
    const c = e.contentChanges[0];
    if (c.text !== ">") return;
    if (
      !vscode.workspace
        .getConfiguration("zx")
        .get<boolean>("autoCloseTags", true)
    )
      return;
    const pos = new vscode.Position(
      c.range.start.line,
      c.range.start.character + c.text.length,
    );
    if (!isInsideReturn(e.document, pos)) return;
    const html = HTMLTextDocument.create(
      e.document.uri.toString(),
      "html",
      e.document.version,
      e.document.getText(),
    );
    const insert = htmlService.doTagComplete(
      html,
      { line: pos.line, character: pos.character },
      htmlService.parseHTMLDocument(html),
    );
    if (!insert) return;
    const ed = vscode.window.activeTextEditor;
    if (
      insert.includes("$") &&
      ed &&
      ed.document.uri.toString() === e.document.uri.toString()
    ) {
      applying = true;
      await ed.insertSnippet(new vscode.SnippetString(insert), pos);
      applying = false;
      return;
    }
    applying = true;
    const we = new vscode.WorkspaceEdit();
    we.insert(e.document.uri, pos, insert);
    await vscode.workspace.applyEdit(we);
    applying = false;
  });

  subs.push(listener);
  if (ctx && "subscriptions" in ctx)
    subs.forEach((s) => ctx.subscriptions.push(s));
  return subs;
}

export default registerHtmlAutoCompletion;
