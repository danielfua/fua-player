# Dados privados e relatórios

Não inclua chaves de API, backups, logs, perfis WebView2, caminhos de mídia ou dados de reprodução em issues e pull requests. O servidor local só atende no loopback e valida Host/Origin nas operações de escrita.

Os pacotes oficiais de dependências são fixados em `dependencies.lock.json`. Atualizações dessas dependências devem atualizar os hashes e passar pelos testes antes de gerar outro instalador.
