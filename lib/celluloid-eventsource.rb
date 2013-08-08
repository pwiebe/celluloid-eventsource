require "celluloid-eventsource/version"

require 'celluloid'
require 'celluloid/io'

module Celluloid
  class EventSource
    include Celluloid

    execute_block_on_receiver :error, :open, :message, :on

    # Get API url
    attr_reader :url
    # Get ready state
    attr_reader :ready_state
    # Get current retry value (in seconds)
    attr_reader :retry
    # Override retry value (in seconds)
    attr_writer :retry
    # Get value of last event id
    attr_reader :last_event_id
    # Get the inactivity timeout
    attr_reader :inactivity_timeout
    # Set the inactivity timeout
    attr_writer :inactivity_timeout
    # Ready state
    # The connection has not yet been established, or it was closed and the user agent is reconnecting.
    CONNECTING = 0
    # The user agent has an open connection and is dispatching events as it receives them.
    OPEN       = 1
    # The connection is not open, and the user agent is not trying to reconnect. Either there was a fatal error or the close() method was invoked.
    CLOSED     = 2


    # Create a new stream
    #
    # url - the url as string
    # query - the query string as hash
    # headers - the headers for the request as hash
    def initialize(url, query={}, body = nil, headers={})
      @url = url
      @query = query
      @query_string = query.map { |k,v| "#{k}=#{v}"}.join('&')
      @headers = headers
      @ready_state = CLOSED

      @last_event_id = nil
      @retry = 3 # seconds
      @inactivity_timeout = 60 # seconds

      @options = {:socket_class => Celluloid::IO::TCPSocket,
                  :ssl_socket_class => Celluloid::IO::SSLSocket}
      @options[:body] = body if body
      @options[:headers] = headers
      @opens = []
      @errors = []
      @messages = []
      @on = {}
    end

    # Add open event handler
    #
    # Returns nothing
    def open(&block)
      @opens << block
    end

    # Add a specific event handler
    #
    # name - name of event
    #
    # Returns nothing
    def on(name, &block)
      @on[name] ||= []
      @on[name] << block
    end

    # Add message event handler
    #
    # Returns nothing
    def message(&block)
      @messages << block
    end

    # Add error event handler
    #
    # Returns nothing
    def error(&block)
      @errors << block
    end


    def start
      @ready_state = CONNECTING
      async.listen
      puts "Exiting START...."
    end

    def close
      self.terminate
    end

    protected

    def listen
      full_url = "#{@url}"
      full_url += "?#{@query_string}" if @query_string
      Http.
           with_headers({'Cache-Control' => 'no-cache', 'Accept' => 'text/event-stream'}).
           on(:request) { |r| puts "REQUEST #{r.inspect}"}.
           on(:response) { |r| puts "RESPONSE #{r.inspect}"; handle_response(r)}.
           on(:connect) { |r| puts "CONNECT #{r.inspect}"; handle_connect(r)}.
           get(full_url, @options
           )
      nil
    rescue => e
      puts "LISTEN EXCEPTION: #{e.class}:#{e.message}"
    end

    def handle_connect(r)
      @connection = r
    end

    def handle_response(r)
      if r.status != 200
        close
        @errors.each { |error| error.call({status: r.status, msg:"Unexpected response status #{r.status}:#{r.class} conn: #{@conn.class} req: #{@req.response}"}) }
      elsif /^text\/event-stream/.match r.headers['Content-Type']
        @ready_state = OPEN
        @opens.each { |open| open.call }

        buffer = ""
        begin
          r.body do |chunk|
            buffer += chunk
            # TODO: manage \r, \r\n, \n
            while index = (buffer.index("\n\n") || buffer.index("\r\n"))
              stream = buffer.slice!(0..index)
              handle_stream(stream)
            end

          end
        rescue => e # ::IO::EOFError
          puts "#{e.class}:#{e.message}    EOFERROR!!!!!!"
          @errors.each { |error| error.call("Closed #{e.class}:#{e.message}") }
          @connection.close
          after(@retry) { start }
        end

      else
        puts "ERROR!!! WRONG CONTENT-TYPE!!!"
      end
    end

    private

    def handle_stream(stream)
      puts "-->#{stream}"
      data = ""
      name = nil
      stream.split("\n").each do |part|
        /^data:(.+)$/.match(part) do |m|
          data += m[1].strip
          data += "\n"
        end
        /^id:(.+)$/.match(part) do |m|
          @last_event_id = m[1].strip
        end
        /^event:(.+)$/.match(part) do |m|
          name = m[1].strip
        end
        /^retry:(.+)$/.match(part) do |m|
          if m[1].strip! =~ /^[0-9]+$/
            @retry = m[1].to_i / 1000 # sent in milliseconds; expect retry to be in seconds
          end
        end
      end
      return if data.empty?
      data.chomp!("\n")
      if name.nil?
        @messages.each { |message| message.call(data) }
      else
        @on[name].each { |message| message.call(data) } if not @on[name].nil?
      end
    end


  end
end

