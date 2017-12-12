module Dapp
  class CLI
    module Command
      class Base < ::Dapp::CLI
        option :dir,
               long: '--dir PATH',
               description: 'Change to directory',
               on: :head

        %w(run_dir build_dir deploy_dir).tap do |dirs|
          dirs.each do |dir|
            option dir.to_sym,
                  long: "--#{dir.gsub("_", "-")} PATH",
                  description: "Directory where reside: build cache, lock files for concurrent dapp operations (DIR/.dapp_build by default). Alias for #{(dirs - [dir]).map{|d| "--" + d.gsub("_", "-")}.join(", ")}."
          end
        end

        option :name,
               long: "--name NAME",
               description: "Use custom dapp name. Chaging default name will cause full cache rebuild. By default dapp name is the last element of remote.origin.url from project git, or it is the name of the directory where Dappfile resides."

        option :quiet,
               short: '-q',
               long: '--quiet',
               description: 'Suppress logging',
               default: false,
               boolean: true

        option :verbose,
               long: '--verbose',
               description: 'Enable verbose output',
               default: false,
               boolean: true

        option :time,
               long: '--time',
               description: 'Enable output with time',
               default: false,
               boolean: true

        option :ignore_config_warning,
               long: '--ignore-config-sequential-processing-warnings',
               default: false,
               boolean: true

        option :color,
               long: '--color MODE',
               description: 'Display output in color on the terminal',
               in: %w(auto on off),
               default: 'auto'

        option :dry_run,
               long: '--dry-run',
               default: false,
               boolean: true

        option :dev,
               long: '--dev',
               default: false,
               boolean: true

        def initialize
          self.class.options.merge!(Base.options)
          super()
        end

        def run_dapp_command(run_method, options: {}, log_running_time: true)
          dapp = ::Dapp::Dapp.new(options: options)

          log_dapp_running_time(dapp, ignore: !log_running_time) do
            begin
              before_dapp_run_command(dapp)

              if block_given?
                yield dapp
              elsif !run_method.nil?
                dapp.public_send(run_method)
              end
            ensure
              dapp.terminate
            end
          end
        end

        def log_dapp_running_time(dapp, ignore: false)
          return yield if ignore

          begin
            start_time = Time.now
            yield
          ensure
            dapp.log_step("Running time #{(Time.now - start_time).round(2)} seconds")
          end
        end

        def run(_argv = ARGV)
          raise
        end

        def before_dapp_run_command(dapp, &blk)
          yield if block_given?
          dapp.try_host_docker_login
        end

        def cli_options(**kwargs)
          dirs = [config[:build_dir], config[:run_dir], config[:deploy_dir]]
          if dirs.compact.size > 1
            self.class.print_error_with_help_and_die! self, "cannot use alias options --run-dir, --build-dir, --deploy-dir at the same time"
          end

          config.merge(build_dir: dirs.compact.first, **kwargs)
        end
      end
    end
  end
end
