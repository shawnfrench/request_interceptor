require "delegate"
require "net/http"

require "rack/mock"

class RequestInterceptor::Runner
  GET = "GET".freeze
  POST = "POST".freeze
  PUT = "PUT".freeze
  DELETE = "DELETE".freeze

  attr_reader :applications

  def initialize(*applications)
    @applications = applications
  end

  def run(&simulation)
    cache_original_nethttp_methods
    override_nethttp_methods
    simulation.call
  ensure
    restore_nethttp_methods
  end

  def request(request, body, &block)
    application = applications.find { |app| app.hostname_pattern === request["Host"] }
    mock_request = Rack::MockRequest.new(application)

    mock_response =
      case request.method
      when GET
        mock_request.get(request.path)
      when POST
        mock_request.post(request.path)
      when PUT
        mock_request.put(request.path)
      when DELETE
        mock_request.delete(request.path)
      else
        raise NotImplementedError, "Simulating #{request.method} is not supported"
      end

    status = RequestInterceptor::Status.from_code(mock_response.status)

    response = status.response_class.new("1.1", status.value, status.description)
    mock_response.original_headers.each { |k, v| response.add_field(k, v) }
    response.body = mock_response.body

    block.call(response) if block

    response
  end

  private

  def cache_original_nethttp_methods
    @original_request_method = Net::HTTP.instance_method(:request)
    @original_start_method = Net::HTTP.instance_method(:start)
    @original_finish_method = Net::HTTP.instance_method(:finish)
  end

  def override_nethttp_methods
    runner = self

    Net::HTTP.class_eval do
      def start
        @started = true
        return yield(self) if block_given?
        self
      end

      def finish
        @started = false
        nil
      end

      define_method(:request) do |request, body = nil, &block|
        runner.request(request, body, &block)
      end
    end
  end

  def restore_nethttp_methods
    Net::HTTP.send(:define_method, :request, @original_request_method)
    Net::HTTP.send(:define_method, :start, @original_start_method)
    Net::HTTP.send(:define_method, :finish, @original_finish_method)
  end
end
