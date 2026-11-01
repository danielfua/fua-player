# Componentes de terceiros

O código específico do Fua Player é disponibilizado sob GPL-3.0-or-later. Os componentes abaixo conservam suas licenças e créditos próprios.

* **mpv/libmpv**: GPL-2.0-or-later na compilação padrão. Copyright e texto GPL incluídos. Versão usada: git `48fca90e8c`, pacote de desenvolvimento Windows x64 de 2026-11-01. Código: https://github.com/mpv-player/mpv/tree/48fca90e8c. Compilador/distribuidor do pacote e receitas de dependências: https://github.com/shinchiro/mpv-winbuild-cmake. URL e SHA-256 do pacote estão em `app/fua-native/runtime-source.json`. libmpv incorpora outras bibliotecas, incluindo FFmpeg; suas condições também se aplicam aos binários. Para redistribuir uma compilação alterada, disponibilize o código-fonte correspondente e as receitas de compilação exigidas pelas licenças aplicáveis.
* **MediaInfoLib 26.05**: BSD-2-Clause; texto em `MediaInfo.html`. Código e distribuições: https://github.com/MediaArea/MediaInfoLib e https://mediaarea.net/MediaInfo.
* **Node.js 24.22.1**: licença MIT e avisos de componentes incorporados em `Node.txt`. Código: https://github.com/nodejs/node/tree/v24.22.1.
* **Microsoft WebView2 SDK 1.0.4314.35**: licença da Microsoft em `WebView2.txt`. O WebView2 Runtime instalado no Windows é um pré-requisito separado.
* **Free My TV**: origem conceitual do projeto inicial; preservamos os créditos MIT em `FreeMyTV-MIT.txt`. O aplicativo Windows não depende do aplicativo Android. Origem: https://github.com/simbasjungles/free-my-tv.

As imagens, fotografias, logotipos e dados de filmes/séries obtidos de TMDB e OMDb pertencem aos respectivos titulares. Não fazem parte do código-fonte nem são distribuídos no catálogo público. Cada instalação usa suas próprias chaves e deve observar os termos desses serviços. Este produto usa a API do TMDB, mas não é endossado nem certificado pelo TMDB.
