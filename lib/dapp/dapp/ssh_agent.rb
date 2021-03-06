module Dapp
  class Dapp
    module SshAgent
      class << self
        def included(_base)
          ::Dapp::Dapp::Shellout::Base.default_env_keys << 'SSH_AUTH_SOCK'
        end
      end # << self

      def run_ssh_agent
        raise 'Cannot fork dapp process: there are active file locks' unless ::Dapp::Dimg::Lock::File.counter.zero?

        sock_name = "dapp-ssh-#{SecureRandom.uuid}"

        "/tmp/#{sock_name}".tap do |sock_path|
          Process.fork do
            Prctl.call(Prctl::PR_SET_PDEATHSIG, Signal.list['TERM'], 0, 0, 0)

            Process.setproctitle sock_name

            @ssh_agent_pid = nil

            Signal.trap('INT') {}
            Signal.trap('TERM') { Process.kill('TERM', @ssh_agent_pid) if @ssh_agent_pid }

            @ssh_agent_pid = Process.fork do
              STDOUT.reopen '/dev/null', 'a'
              STDERR.reopen '/dev/null', 'a'
              exec 'ssh-agent', '-d', '-a', sock_path
            end

            Process.wait @ssh_agent_pid
          end

          begin
            ::Timeout.timeout(10) do
              sleep 0.001 until File.exist? sock_path
            end
          rescue ::Timeout::Error
            raise Error::Dapp, code: :cannot_run_ssh_agent
          end
        end # sock_path
      end

      def add_ssh_key(ssh_key_path)
        shellout! "ssh-add #{ssh_key_path}", env: { SSH_AUTH_SOCK: ssh_auth_sock(force_run_agent: true) }
      end

      def ssh_agent_exist?
        ENV['SSH_AUTH_SOCK'] && File.exist?(ENV['SSH_AUTH_SOCK'])
      end

      def default_ssh_keys
        @default_ssh_keys ||= begin
          %w(id_rsa id_dsa).map do |path|
            File.join(ENV["HOME"], ".ssh", path)
          end.select do |path|
            File.exist? path
          end
        end
      end

      def ssh_auth_sock(force_run_agent: false)
        @ssh_auth_sock ||= begin
          system_ssh_auth_sock = nil
          system_ssh_auth_sock = File.expand_path(ENV['SSH_AUTH_SOCK']) if ssh_agent_exist?

          if force_run_agent
            run_ssh_agent.tap { |ssh_auth_sock| ENV['SSH_AUTH_SOCK'] = ssh_auth_sock }
          else
            system_ssh_auth_sock
          end
        end
      end

      def setup_ssh_agent
        if options[:ssh_key]
          options[:ssh_key].each do |ssh_key|
            raise Error::Dapp, code: :ssh_key_not_found, data: { path: ssh_key } unless File.exist? ssh_key

            File.chmod 0o600, ssh_key
            add_ssh_key ssh_key
          end
        elsif (not ssh_agent_exist?) and default_ssh_keys.any?
          default_ssh_keys.each do |ssh_key|
            add_ssh_key ssh_key
          end
        end
      end
    end # SshAgent
  end # Dapp
end # Dapp
