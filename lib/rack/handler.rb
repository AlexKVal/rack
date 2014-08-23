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
      def get(server_name)
        return unless server_name

        handler_class = get_handler_class(server_name)
        raise (@load_error || @name_error) unless handler_class
        handler_class
      end

      # Select first available Rack handler given an `Array` of server names.
      # Raises `LoadError` if no handler was found.
      #
      #   > pick ['thin', 'webrick']
      #   => Rack::Handler::WEBrick
      def pick(server_names)
        server_names = Array(server_names)
        server_names.each do |server_name|
          handler_class = get_handler_class(server_name)
          return handler_class if handler_class
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

      # name - can be a server-name for registered handlers e.g. 'cgi',
      # or constant_name of handler class e.g. "Rack::Handler::CGI".
      def get_handler_class(name)
        name = name.to_s
        try_require_if_unregistered name
        try_get_handler_class name
      end

      # File name from class name:
      #
      #   Foo # => 'foo'
      #   FooBar # => 'foo_bar'
      #   FooBarBaz # => 'foo_bar_baz'
      def underscore(string)
        string.gsub(/^[A-Z]+/) { |pre| pre.downcase }.gsub(/[A-Z]+[^A-Z]/, '_\&').downcase
      end

      # Foo::Bar::Baz from 'Foo::Bar::Baz'
      def class_from_string(string)
        string.split("::").inject(Object) { |o, x| o.const_get(x) }
      end

      # If server class is not registered yet, try to require file with the name
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

      # Try to get handler, if registered, by server-name.
      # Otherwise get it by name of handler class.
      # name - can be a server-name for registered handlers e.g. 'cgi',
      # or constant_name of handler class e.g. "Rack::Handler::CGI".
      # returns nil, if nothing was found.
      def try_get_handler_class(name)
        @name_error = nil
        if handler_class_name = @handlers[name]
          class_from_string handler_class_name
        else
          const_get name
        end
      rescue NameError => error
        @name_error = error
        nil
      end

      def register(name, klass)
        @handlers ||= {}
        @handlers[name.to_s] = klass.to_s
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
