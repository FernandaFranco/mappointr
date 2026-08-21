# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# You can control the number of workers using ENV["WEB_CONCURRENCY"]. You
# should only set this value when you want to run 2 or more workers. The
# default is already 1. You can set it to `auto` to automatically start a worker
# for each available processor.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Roda o supervisor do Solid Queue (dispatcher + workers do RoomSweepJob)
# dentro do próprio processo do Puma, em vez de um processo `bin/jobs`
# separado. Dois motivos, não só preferência: (1) config/cable.yml usa o
# adapter `async` em desenvolvimento — um pub/sub só válido dentro do MESMO
# processo, então um broadcast disparado por um processo de job separado
# nunca chegaria aos navegadores conectados ao servidor web; (2) este repo
# não tem infraestrutura de deploy pra um segundo processo (sem Kamal, sem
# Procfile de produção, Dockerfile de um único CMD) — o plugin evita
# inventar uma topologia nova só pra isso.
#
# IMPORTANTE: o modo padrão do plugin (`:fork`) cria um processo do SO
# separado — copy-on-write depois do fork, então o pub/sub em memória do
# adapter `async` NÃO seria compartilhado, recriando exatamente o problema
# que queremos evitar. `solid_queue_mode :async` é o que garante que o
# supervisor roda como threads dentro do MESMO processo Ruby.
#
# Nunca em test: config.active_job.queue_adapter fica em :test lá (síncrono,
# não usa as tabelas do Solid Queue de jeito nenhum), então o supervisor não
# teria nenhum propósito ali — só threads extras de polling competindo pelo
# pool de conexões durante o boot do Puma que os testes de sistema (Capybara)
# sobem. Cogitamos que isso explicasse uma falha intermitente de timing no
# passo de login dos testes de sistema, mas o mesmo flake persistiu depois
# desse ajuste (e já acontecia em specs sem nenhuma relação com salas) — não
# é a causa, e o flake em si segue sem investigar. Mantemos o gate assim
# mesmo, só por remover overhead que genuinamente não serve pra nada em test.
#
# Re-verificado no upgrade pro Rails 8.1: o gerador do app:update sobrescreve
# esse arquivo com o bloco padrão (`plugin :solid_queue if
# ENV["SOLID_QUEUE_IN_PUMA"]`, sem `solid_queue_mode :async` e sem o gate de
# test) — a lógica abaixo foi restaurada manualmente de propósito. O motivo
# de existir é o adapter `async` do ActionCable, que não mudou neste upgrade.
if ENV.fetch("SOLID_QUEUE_IN_PUMA", "true") == "true" && ENV["RAILS_ENV"] != "test"
  plugin :solid_queue
  solid_queue_mode :async
end

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
