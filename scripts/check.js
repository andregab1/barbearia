const { execFileSync } = require('child_process');
const { readdirSync, statSync } = require('fs');
const { join } = require('path');

function arquivosJs(diretorio) {
  return readdirSync(diretorio).flatMap((nome) => {
    const caminho = join(diretorio, nome);
    if (nome === 'node_modules' || nome === 'backend') return [];
    return statSync(caminho).isDirectory() ? arquivosJs(caminho) : caminho.endsWith('.js') ? [caminho] : [];
  });
}

for (const arquivo of arquivosJs(process.cwd())) {
  execFileSync(process.execPath, ['--check', arquivo], { stdio: 'inherit' });
}
console.log('Sintaxe JavaScript validada.');
