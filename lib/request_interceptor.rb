require "request_interceptor/version"

module RequestInterceptor
  def self.define(hostname_pattern, &block)
    Class.new(Application, &block).tap do |app|
      app.hostname_pattern = hostname_pattern
    end
  end

  def self.run(*applications, &simulation)
    Runner.new(*applications).run(&simulation)
  end
end

require "request_interceptor/application"
require "request_interceptor/runner"
require "request_interceptor/status"