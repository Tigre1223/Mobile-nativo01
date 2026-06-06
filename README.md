# Controle Financeiro

Projeto Flutter criado a partir do prototipo da Parte 1 para um app funcional de controle financeiro.

## Recursos implementados

- Login e cadastro com validacao.
- Persistencia local com SQLite.
- Compatibilidade com Flutter Web usando `sqflite_common_ffi_web`.
- Estado reativo com `provider`.
- CRUD de transacoes na interface: adicionar, listar, alterar e remover.
- Dashboard com saldo, receitas e despesas calculados automaticamente.
- Tela de analise financeira.
- Estrutura em estilo MVVM: Models, Repositories, ViewModels e Views.
- Arquivos web do SQLite gerados em `web/sqlite3.wasm` e `web/sqflite_sw.js`.

## Como abrir no Chrome

De dois cliques no arquivo:

```text
abrir_app_no_chrome.bat
```

Ele inicia o servidor Flutter Web na porta `52931`, se ainda nao estiver rodando, e abre:

```text
http://127.0.0.1:52931
```

## Como rodar pelo terminal

Usando o Flutter SDK baixado no workspace:

```bash
..\work\flutter_sdk\flutter\bin\flutter.bat run -d web-server --web-hostname 127.0.0.1 --web-port 52931
```

Depois abra no Chrome:

```text
http://127.0.0.1:52931
```

## Validacao

Comandos usados na revisao:

```bash
flutter analyze
flutter test
flutter build web
```
