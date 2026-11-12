// ts_check.js — проверка СИНТАКСИСА TypeScript-файла (без проверки типов).
// usage: node ts_check.js <file.ts> <path-to-typescript.js>
// exit 0 = синтаксис ок, exit 2 = ошибки (печатает первые 5), exit 3 = не смог запуститься.
const fs = require('fs');
const path = require('path');

const file = process.argv[2];
const tsLib = process.argv[3] ? path.resolve(process.argv[3]) : '';
if (!file || !tsLib) {
  console.error('usage: node ts_check.js <file.ts> <typescript.js>');
  process.exit(3);
}

let ts;
try {
  ts = require(tsLib);
} catch (e) {
  console.error('не загрузить typescript: ' + e.message);
  process.exit(3);
}

let src;
try {
  src = fs.readFileSync(file, 'utf8');
} catch (e) {
  console.error('не прочитать файл: ' + e.message);
  process.exit(3);
}

const out = ts.transpileModule(src, {
  fileName: file,
  reportDiagnostics: true,
  compilerOptions: {
    target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.ESNext,
    jsx: ts.JsxEmit.ReactJSX,
  },
});

const diags = out.diagnostics || [];
if (diags.length) {
  diags.slice(0, 5).forEach((d) => {
    let pos = '';
    if (d.file && typeof d.start === 'number') {
      const p = d.file.getLineAndCharacterOfPosition(d.start);
      pos = ':' + (p.line + 1) + ':' + (p.character + 1);
    }
    console.error('ERROR' + pos + ' ' + ts.flattenDiagnosticMessageText(d.messageText, ' '));
  });
  process.exit(2);
}
process.exit(0);
