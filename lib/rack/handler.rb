module Rack
  # *Handlers* connect web servers with Rack.
  #
  # Rack includes Handlers for Thin, WEBrick, FastCGI, CGI, SCGI
  # and LiteSpeed.
  #
  # Handlers usually are activated by calling <tt>MyHandler.run(myapp)</tt>.
  # A second optional hash can be passed to include server-specific
  # configuration.
  module Handler
    class << self
      def get(server)
        return unless server
        server = server.to_s

        try_require_if_unregistered server

        server_class = try_get_server_class server
        raise (@load_error || @name_error) unless server_class
        server_class
      end

      # Select first available Rack handler given an `Array` of server names.
      # Raises `LoadError` if no handler was found.
      #
      #   > pick ['thin', 'webrick']
      #   => Rack::Handler::WEBrick
      def pick(server_names)
        server_names = Array(server_names)
        server_names.each do |server_name|
          begin
            return get(server_name.to_s)
          rescue LoadError, NameError
          end
        end

        raise LoadError, "Couldn't find handler for: #{server_names.join(', ')}."
      end

      def default(options = {})
        # Guess.
        if ENV.include?("PHP_FCGI_CHILDREN")
          # We already speak FastCGI
          options.delete :File
          options.delete :Port

          Rack::Handler::FastCGI
        elsif ENV.include?("REQUEST_METHOD")
          Rack::Handler::CGI
        elsif ENV.include?("RACK_HANDLER")
          get(ENV["RACK_HANDLER"])
        else
          pick ['thin', 'puma', 'webrick']
        end
      end

      # Conventions:
      #
      #   Foo # => 'foo'
      #   FooBar # => 'foo_bar'
      #   FooBarBaz # => 'foo_bar_baz'
      def underscore(string)
        string.gsub(/^[A-Z]+/) { |pre| pre.downcase }.gsub(/[A-Z]+[^A-Z]/, '_\&').downcase
      end

      def class_from_string(string)
        string.split("::").inject(Object) { |o, x| o.const_get(x) }
      end

      # If server class is not registered yet, try to require file with name
      # got from server-name constant transformed into canonical form filename.
      # Silences the LoadError if not found.
      def try_require_if_unregistered(const_name)
        @load_error = nil
        unless @handlers.include?(const_name)
          require ::File.join('rack/handler', underscore(const_name))
        end
      rescue LoadError => error
        @load_error = error
      end

      def try_get_server_class(server)
        @name_error = nil
        if server_class_name = @handlers[server]
          class_from_string server_class_name
        else
          const_get server
        end
      rescue NameError => error
        @name_error = error
        nil
      end

      def register(server, klass)
        @handlers ||= {}
        @handlers[server.to_s] = klass.to_s
      end
    end

    autoload :CGI, "rack/handler/cgi"
    autoload :FastCGI, "rack/handler/fastcgi"
    autoload :Mongrel, "rack/handler/mongrel"
    autoload :EventedMongrel, "rack/handler/evented_mongrel"
    autoload :SwiftipliedMongrel, "rack/handler/swiftiplied_mongrel"
    autoload :WEBrick, "rack/handler/webrick"
    autoload :LSWS, "rack/handler/lsws"
    autoload :SCGI, "rack/handler/scgi"
    autoload :Thin, "rack/handler/thin"

    register 'cgi', 'Rack::Handler::CGI'
    register 'fastcgi', 'Rack::Handler::FastCGI'
    register 'mongrel', 'Rack::Handler::Mongrel'
    register 'emongrel', 'Rack::Handler::EventedMongrel'
    register 'smongrel', 'Rack::Handler::SwiftipliedMongrel'
    register 'webrick', 'Rack::Handler::WEBrick'
    register 'lsws', 'Rack::Handler::LSWS'
    register 'scgi', 'Rack::Handler::SCGI'
    register 'thin', 'Rack::Handler::Thin'
  end
end
