require 'open3'
require 'socket'
require 'timeout'

def sh!(cmd)
  unless system(cmd)
    raise "[#{cmd}] failed with exit code #{$?.exitstatus}"
  end
end

def app_ready?(pid, port)
  Process.getpgid(pid) && port_open?(port)
end

def create_app(name, env = {})
  rails_new_options = %w(-T -J -S --skip-spring --skip-listen)
  rails_new_options << "-O" if name == 'idp'
  Dir.chdir(File.expand_path('../../support', __FILE__)) do
    FileUtils.rm_rf(name)
    system(env, "rails", "new", name, *rails_new_options, "-m", "#{name}_template.rb")
  end
end

def start_app(name, port, options = {})
  pid = nil
  Bundler.with_clean_env do
    Dir.chdir(File.expand_path("../../support/#{name}", __FILE__)) do
      pid = Process.spawn("bundle exec rails server -p #{port} -e production", out: "log/#{name}.log", err: "log/#{name}.err.log")
      sleep 1 until app_ready?(pid, port)
      if app_ready?(pid, port)
        puts "Launched #{name} on port #{port} (pid #{pid})..."
      else
        raise "#{name} failed to start"
      end
    end
  end
  pid
end

def stop_app(pid)
  if pid
    Process.kill(:INT, pid)
    Process.wait(pid)
  end
end

def port_open?(port)
  Timeout::timeout(1) do
    begin
      s = TCPSocket.new('127.0.0.1', port)
      s.close
      return true
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      return false
    end
  end
rescue Timeout::Error
  false
end
