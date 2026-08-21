# Mappointr

Jogo de geografia: o app sorteia um país, o jogador clica no mapa onde acha que ele fica,
e o app usa PostGIS para medir o quão perto o chute ficou da fronteira real.

## Stack

- Ruby 3.4.3, Rails 8.1.3.1 (`config.load_defaults 8.1`)
- PostgreSQL + PostGIS via `activerecord-postgis-adapter` (adapter: `postgis`)
- Devise para autenticação
- Hotwire (Turbo + Stimulus) com importmap — **sem build de JS, sem node_modules**
- Tailwind via `tailwindcss-rails` (gera `app/assets/builds/tailwind.css`)
- Leaflet 1.9.4 carregado por CDN em `app/views/layouts/application.html.erb`,
  usado como global `L` dentro dos controllers Stimulus
- Minitest + fixtures (não RSpec, não FactoryBot)

## Comandos

```bash
bin/dev                      # servidor + tailwind watch (Procfile.dev)
bin/rails test               # suíte de testes
bin/rails test:system        # testes de sistema (precisa de Chrome)
bin/rails db:test:prepare    # recria o banco de teste a partir do schema
bin/rubocop                  # lint (rubocop-rails-omakase)
bin/brakeman --no-pager      # scan de segurança
bin/rails countries:import   # importa países do Natural Earth (lib/tasks/countries.rake)
bin/rails countries:stats    # estatísticas dos países no banco
```

CI (`.github/workflows/ci.yml`) roda: brakeman, `bin/importmap audit`, rubocop e
`bin/rails db:test:prepare test test:system`. Antes de dar push, rode ao menos
`bin/rubocop` e `bin/rails test`.

## Domínio

- `Country` — nome (`name` em inglês, `name_pt` exibido ao jogador), `difficulty`
  (enum easy/medium/hard), flag `excluded` e `boundary` (geography multi_polygon,
  SRID 4326). O escopo `playable` filtra `excluded: false`.
- `GameRound` — pertence a user + country. Um callback `before_validation` calcula
  `distance_km` via PostGIS e deriva o enum `result`: `correct` (distância 0),
  `close` (≤ `CLOSE_THRESHOLD_KM`, 500km) ou `wrong`.
- `User` — Devise, com métodos de estatística (`accuracy_percentage`, etc.) que
  ainda não têm view.

Fluxo de jogo: `GamesController#new` sorteia o país e guarda
`session[:current_country_id]` + `session[:round_started_at]`. O clique no mapa é
capturado por `map_controller.js`, que monta um form e faz POST para `/play`.
`#create` lê o país **da sessão** (nunca dos params — é o que impede trapaça) e
calcula o tempo. `#show` exibe o resultado com estatísticas comparativas.

## Convenções

- **Comentários de código e todo texto de interface são em português (pt-BR).**
  Nomes de classes, métodos, colunas e rotas ficam em inglês. Siga esse padrão.
- Estilo Ruby: `rubocop-rails-omakase` (aspas duplas, sem frozen_string_literal
  obrigatório). Rode `bin/rubocop -a` antes de finalizar.
- Consultas PostGIS hoje são SQL cru dentro de `Country`, montado com
  interpolação de string. Ao mexer ali, prefira `sanitize_sql_array` / bind
  params — não copie o padrão de interpolação para código novo.
- Stimulus: um controller por arquivo em `app/javascript/controllers/`, registrado
  automaticamente por `pin_all_from`. `hello_controller.js` é resto de scaffold.

## Armadilhas conhecidas

- **Minitest está pinado em `~> 5.25`** no Gemfile. Não é mais o bug antigo do Rails 7.2
  (`line_filtering.rb`/`run/3`, corrigido no upstream) — o Minitest 6 separou
  `minitest/mock` do core, e `test/models/room_test.rb` faz `require "minitest/mock"`
  direto. Soltar o pin quebra esse require. Pra soltar de vez, teria que migrar esse
  require pra uma gem de mock separada primeiro.
- Fixtures de `countries` precisam de `boundary` em EWKT
  (`"SRID=4326;MULTIPOLYGON(((...)))"`), senão as consultas PostGIS retornam nil.
  Fixtures não disparam callbacks, então `distance_km`/`result` de `game_rounds`
  são escritos à mão nos arquivos de fixture.
- Fixtures de `users` precisam de `encrypted_password` gerado com
  `<%= Devise::Encryptor.digest(User, "password123") %>`.
- `Country#distance_from` arredonda para 1 casa decimal e `GameRound` arredonda de
  novo com `.round` (não `.to_i`) — usar `.to_i` truncava chutes a menos de 1km
  **fora** da fronteira para distância 0, premiando como `correct`. Já corrigido;
  não reintroduza o truncamento.
- `test/system/` cobre salas multiplayer (`rooms_test.rb`) e a página de estatísticas
  (`stats_test.rb`), mas não tem cobertura de sistema pro fluxo solo de jogo
  (`games#new` → clique no mapa → `games#create`) — só teste de controller.
