require 'rack/handler'

class Rack::Handler::Lobster; end
class RockLobster; end

module Rack
  module Handler
    class WithoutOptions
      # has no method #valid_options for tests purpose
    end
    register :without_options, WithoutOptions
  end
end

module Rack
  module Handler
    class WithOptions
      def self.valid_options
        {
          "Opt1" => "option1 desc",
          "Opt2" => "option2 desc",
          "Opt3" => "option3 desc",
          "Host=HOST" => "Hostname to listen on (default: localhost)",
          "Port=PORT" => "Port to listen on (default: 8080)",
        }
      end
    end
    register :with_options, WithOptions
  end
end

describe Rack::Handler do
  it "has registered default handlers" do
    Rack::Handler.get('cgi').should.equal Rack::Handler::CGI
    Rack::Handler.get('webrick').should.equal Rack::Handler::WEBrick

    begin
      Rack::Handler.get('fastcgi').should.equal Rack::Handler::FastCGI
    rescue LoadError
    end

    begin
      Rack::Handler.get('mongrel').should.equal Rack::Handler::Mongrel
    rescue LoadError
    end
  end

  should "raise LoadError if handler doesn't exist" do
    lambda {
      Rack::Handler.get('boom')
    }.should.raise(LoadError)
  end

  should "get unregistered, but already required, handler by name" do
    Rack::Handler.get('Lobster').should.equal Rack::Handler::Lobster
  end

  should "register custom handler" do
    Rack::Handler.register('rock_lobster', 'RockLobster')
    Rack::Handler.get('rock_lobster').should.equal RockLobster
  end

  should "not need registration for properly coded handlers even if not already required" do
    begin
      $LOAD_PATH.push File.expand_path('../unregistered_handler', __FILE__)
      Rack::Handler.get('Unregistered').should.equal Rack::Handler::Unregistered
      lambda {
        Rack::Handler.get('UnRegistered')
      }.should.raise LoadError
      Rack::Handler.get('UnregisteredLongOne').should.equal Rack::Handler::UnregisteredLongOne
    ensure
      $LOAD_PATH.delete File.expand_path('../unregistered_handler', __FILE__)
    end
  end

  should "allow autoloaded handlers to be registered properly while being loaded" do
    path = File.expand_path('../registering_handler', __FILE__)
    begin
      $LOAD_PATH.push path
      Rack::Handler.get('registering_myself').should.equal Rack::Handler::RegisteringMyself
    ensure
      $LOAD_PATH.delete path
    end
  end

  describe '#handler_opts' do
    should "return empty string when handler is without options" do
      Rack::Handler.handler_opts({:server => 'without_options'}).should.equal ''
    end

    should "return text with handler options when handler is with options" do
      result = Rack::Handler.handler_opts({:server => 'with_options'})
      result.should.not.equal ''
      result.should.match(/Opt1/)
      result.should.match(/Opt2/)
      result.should.match(/Opt3/)
    end

    should "ignore Host and Port options of handler" do
      result = Rack::Handler.handler_opts({:server => 'with_options'})
      result.should.not.equal ''
      result.should.not.match(/Host/)
      result.should.not.match(/Port/)
    end

    # it shouldn't be acting this way:
    it "raises LoadError, for now, but it is wrong; when handler was not found" do
      lambda {
        Rack::Handler.new.handler_opts({:server => 'non_exsisting'})
      }.should.raise LoadError
    end

    # it should be acting this way:
    # should "return Warning-text when handler was not found" do
    #   result = Rack::Server::Options.new.handler_opts({:server => 'non_exsisting'})
    #   result.should.not.equal ''
    #   result.should.match(/Warning/)
    # end
  end
end
