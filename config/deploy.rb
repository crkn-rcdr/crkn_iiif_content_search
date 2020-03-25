# config valid for current version and patch releases of Capistrano

set :application, "contentsearch"
set :repo_url, "https://github.com/sul-dlss/content_search.git"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/opt/app/contentsearch/contentsearch"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, ->{ ["config/master.key", "config/honeybadger.yml", "config/newrelic.yml", "tmp/harvest_purl_fetcher_job_last_run_#{fetch(:rails_env)}"] }

# Default value for linked_dirs is []
append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "config/settings"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

# honeybadger_env otherwise defaults to rails_env
set :honeybadger_env, fetch(:stage)

# update shared_configs before restarting app
before 'deploy:restart', 'shared_configs:update'

set :whenever_roles, [:indexer]

namespace :deploy do
  after :restart, :restart_sidekiq do
    on roles(:app) do
      sudo :systemctl, "restart", "sidekiq-*", raise_on_non_zero_exit: false
    end
  end
end
