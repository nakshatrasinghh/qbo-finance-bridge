# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.
#
# QuickBooks connection and token state belongs to this Rails process. Puma
# cluster mode would split that state across workers, so only single mode is safe.
worker_setting = ENV["WEB_CONCURRENCY"].to_s.strip
unless worker_setting.empty?
  worker_count = Integer(worker_setting, 10, exception: false)
  unless worker_count == 0
    raise "WEB_CONCURRENCY must be unset or 0; this sandbox requires Puma single mode."
  end
end

workers 0

cluster { raise "Puma cluster mode is unsupported; this sandbox requires one Rails process." }

# Thread concurrency remains available inside the single Rails process.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT", 3000)

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
