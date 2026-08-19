# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# to prioritize throughput over latency.
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
if ENV.fetch("SOLID_QUEUE_IN_PUMA", "true") == "true"
  plugin :solid_queue
  solid_queue_mode :async
end

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
