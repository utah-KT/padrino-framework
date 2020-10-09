ENV['RACK_ENV'] = 'test'

require 'padrino-core'

require 'minitest/autorun'
require 'minitest/benchmark'
require 'rack/test'

module MockBenchmark
  include Rack::Test::Methods

  module Settings
    def bench_range
      [20, 80, 320, 1280]
    end

    def run(*)
      puts 'Running ' + self.name
      puts `pmap -x #{$$} | tail -1`
      super
      puts `pmap -x #{$$} | tail -1`
    end
  end

  def self.paths
    @paths ||= (1..100).map{ rand(36**8).to_s(36) }
  end

  def self.included(base)
    base.extend Settings
  end

  def result_code
    ''
  end

  def app
    @app
  end

  module BenchmarkRouting
    def bench_calling_404
      assert_performance_linear 0.99 do |n|
        n.times do
          get "/#{@paths.sample}_not_found"
        end
      end
      assert_equal 404, last_response.status
    end

    def bench_calling_one_path
      assert_performance_linear 0.99 do |n|
        n.times do
          get '/foo'
        end
      end
      assert_equal 200, last_response.status
    end

    def bench_calling_sample
      assert_performance_linear 0.99 do |n|
        n.times do
          get "/#{@paths.sample}"
        end
      end
      assert_equal 200, last_response.status
    end

    def bench_calling_params
      assert_performance_linear 0.99 do |n|
        n.times do
          get "/foo?foo=bar&zoo=#{@paths.sample}"
        end
      end
      assert_equal 200, last_response.status
    end

    def bench_sample_and_params
      assert_performance_linear 0.99 do |n|
        n.times do
          get "/#{@paths.sample}?foo=bar&zoo=#{@paths.sample}"
        end
      end
      assert_equal 200, last_response.status
    end
  end
end

class Padrino::HugeRouterBenchmark < Minitest::Benchmark
  include MockBenchmark

  def setup
    @apps = {}
    @pathss = {}
    @requests = {}
    self.class.bench_range.each do |n|
      @pathss[n] = paths = (1..n/20).map{ rand(36**8).to_s(36) }
      @apps[n] = Sinatra.new Padrino::Application do
        paths.each do |p|
          get("/#{p}") { p.to_s }
        end
      end
      @requests[n] = Rack::MockRequest.new(@apps[n])
      @requests[n].get('/')
    end
  end

  def bench_calling_sample
    response = nil
    assert_performance_linear 0.99 do |n|
      n.times do
        response = @requests[n].get("/#{@pathss[n].sample}")
      end
    end
    assert_equal 200, response.status
  end
end
