# Fua Player

<p align="center"><img src="docs/fua-player.svg" width="128" alt="Fua Player"></p>

Player de mídia para Windows x64, com biblioteca de filmes e séries, reprodução integrada via libmpv e interface em português.

## Recursos

* Capas, logos, sinopses, elenco, temporadas, episódios e informações técnicas dos arquivos.
* Retomada por episódio e leitura/gravação dos arquivos de progresso compatíveis com Nova Video Player.
* Preferência por áudio PT-BR; legenda forçada em português quando o áudio é português e legenda completa em português para áudio original, se as faixas forem identificadas no arquivo.
* Áudio e legendas com listas roláveis; legendas ASS/SSA, SRT e PGS suportadas pelo motor.
* Atalhos editáveis, ajustes de imagem, informações de reprodução em páginas e retorno à biblioteca ao terminar.
* RTX Video HDR para fontes SDR quando GPU, driver e tela forem compatíveis; conteúdo HDR nativo segue o caminho HDR do motor. O recurso depende do hardware e das configurações do Windows.
* Backup/restauração de preferências, atalhos, catálogo e progresso; cópia automática diária. As chaves de API só entram em backups quando a opção correspondente é marcada.

## Instalar

Execute o instalador gerado em `dist/FuaPlayer-Setup-1.0.0.exe`. Ele instala para o usuário atual, sem precisar de administrador, e cria o atalho **Fua Player**. Node.js, libmpv e MediaInfo acompanham o pacote; não é necessário ter Codex, mpv.net, MPC-HC ou outro player instalado.

Pré-requisitos do sistema: Windows 10/11 x64, .NET Framework 4.8 e [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/). A instalação do Runtime é separada quando ele ainda não está disponível no Windows.

Na engrenagem da biblioteca, adicione as pastas de filmes/séries e configure sua própria chave [TMDB](https://www.themoviedb.org/settings/api). A chave [OMDb](https://www.omdbapi.com/apikey.aspx) é opcional para as notas disponíveis no serviço. O catálogo público não contém mídias, chaves, títulos pessoais nem histórico de reprodução.

## Backup e restauração

Engrenagem → **Backup e restauração** → **Criar backup**. O arquivo `.fua-backup.json` pode ser guardado fora do computador. **Restaurar backup** cria uma cópia de segurança antes de aplicar os dados. Os vídeos não entram no backup.

Preferências e cache ficam na subpasta `data` da instalação; backups automáticos ficam em `data/backups`. O progresso compatível com Nova também usa arquivos laterais nas pastas dos vídeos. Para outro computador, configure as novas pastas e confira os caminhos ao restaurar. Backups que incluem chaves devem ser tratados como arquivos privados.

## Compilar

No PowerShell, a partir da raiz do repositório:

```powershell
./scripts/get-dependencies.ps1
./app/node.exe ./tests/backup.test.cjs
./scripts/build-release.ps1
```

O download usa versões fixadas e verifica SHA-256 conforme `dependencies.lock.json`. O compilador C# do .NET Framework e o `tar.exe` do Windows são usados na compilação. Binários, pacotes, caches, preferências e chaves são ignorados pelo Git.

O aplicativo usa um serviço HTTP restrito a `127.0.0.1:8780`. Não é um servidor para acesso pela rede. `FUA_DATA_DIR` permite escolher outro diretório de dados para desenvolvimento e testes.

## Atalhos iniciais

Espaço: play/pause; setas: avanço/volume; F ou F11: tela cheia; A: menu de áudio; V: menu de legendas; J: exibir/ocultar legenda; K: percorrer informações; Ctrl+K: editar atalhos. Números 1–8 ajustam contraste, brilho, gama e saturação.

## Licença e créditos

GPL-3.0-or-later para o código do Fua Player. Consulte `LICENSE` e `licenses/THIRD-PARTY.md` para componentes de terceiros e respectivas origens. Cada serviço de metadados tem seus próprios termos. Este produto usa a API do TMDB, mas não é endossado nem certificado pelo TMDB.
