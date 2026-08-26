# Mappointr

Jogo de geografia: o app sorteia um país, você clica no mapa onde acha que ele
fica, e o PostGIS mede exatamente o quão perto (ou longe) o chute ficou da
fronteira real. Dá pra jogar sozinho, contra o histórico de todo mundo que já
tentou aquele país, ou em tempo real com amigos numa sala multiplayer.

Sem cadastro: todo visitante já entra jogando. Um jogador é criado
silenciosamente na primeira visita, identificado só pela sessão do navegador —
sem e-mail, sem senha, sem formulário de login.

## Funcionalidades

- **Modo solo** — sorteia um país (a dificuldade se ajusta ao seu desempenho
  recente), você clica no mapa, e o resultado mostra a distância até a
  fronteira, os chutes de todo mundo que já jogou aquele país, e como você se
  saiu comparado a eles.
- **Salas multiplayer** — crie uma sala, compartilhe o código com amigos, e
  joguem várias rodadas em tempo real (Turbo Streams via ActionCable) com
  placar ao final.
- **Estatísticas globais** (`/stats`) — para cada país já jogado: quantas
  vezes foi tentado, % de acerto/quase/erro, distância média do chute.
- **Mapa self-hosted** — o contorno de todos os países é servido pelo próprio
  app (sem depender de tile server externo ou chave de API).

## Stack

- Ruby 3.4 + Rails 8.1
- PostgreSQL com [PostGIS](https://postgis.net/) (`activerecord-postgis-adapter`)
  para os cálculos de distância/fronteira
- [Hotwire](https://hotwired.dev/) (Turbo + Stimulus) via importmap — sem
  build de JS, sem `node_modules`
- [Tailwind CSS](https://tailwindcss.com/) via `tailwindcss-rails`
- [Leaflet](https://leafletjs.com/) para o mapa interativo
- [Solid Queue](https://github.com/rails/solid_queue) para jobs em background
- Minitest + fixtures para os testes (unitários, integração e sistema)

## Rodando localmente

Pré-requisitos: Ruby 3.4.3 (veja `.ruby-version`), PostgreSQL com a extensão
PostGIS disponível, e Chrome/Chromium instalado (para os testes de sistema).

```bash
git clone <url-do-repo>
cd mappointr

bin/setup --skip-server      # instala gems, prepara o banco, limpa logs/tmp
bin/rails countries:import   # popula a tabela countries a partir do Natural Earth
bin/dev                      # servidor Rails + Tailwind em modo watch (Procfile.dev)
```

O app fica disponível em `http://localhost:3000`.

## Testes

```bash
bin/rails test               # testes unitários e de integração
bin/rails test:system        # testes de sistema, dirige um Chrome de verdade
bin/rails db:test:prepare    # recria o banco de teste a partir do schema
```

## Lint e segurança

```bash
bin/rubocop              # lint (rubocop-rails-omakase)
bin/brakeman --no-pager  # scan de vulnerabilidades
bin/importmap audit       # audita dependências JS pinadas no importmap
```

O CI (`.github/workflows/ci.yml`) roda essas três checagens mais a suíte de
testes completa em todo push/PR.

## Domínio

- **`Country`** — nome em inglês e em português, dificuldade (easy/medium/hard)
  e a fronteira (`boundary`, geography multi-polígono, SRID 4326).
- **`GameRound`** — uma jogada: usuário, país, coordenada do chute. Calcula a
  distância até a fronteira via PostGIS e deriva o resultado (acerto/quase/erro).
- **`User`** — só um apelido gerado automaticamente. Sem login: a identidade
  é a sessão do navegador (`session[:user_id]`).
- **`Room` / `RoomRound` / `RoomPlayer`** — salas multiplayer: várias rodadas
  cronometradas, sincronizadas entre jogadores via Turbo Streams.

Mais detalhes de arquitetura e convenções do projeto estão em `CLAUDE.md`.

## Deploy

O `Dockerfile` do repositório builda uma imagem de produção pronta (multi-stage,
assets precompilados). Variáveis de ambiente esperadas em produção:

- `RAILS_MASTER_KEY` — para decriptar `config/credentials.yml.enc`
- `MAPPOINTR_DATABASE_PASSWORD` — senha do Postgres
