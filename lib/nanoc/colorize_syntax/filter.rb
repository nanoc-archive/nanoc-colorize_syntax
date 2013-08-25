# encoding: utf-8

require 'nokogiri'
require 'stringio'
require 'open3'

module Nanoc::ColorizeSyntax

  class Filter < Nanoc::Filter

    identifier :colorize_syntax

    # The default colorizer to use for a language if the colorizer for that
    # language is not overridden.
    DEFAULT_COLORIZER = :coderay

    def run(content, params={})
      # Take colorizers from parameters
      @colorizers = Hash.new(params[:default_colorizer] || DEFAULT_COLORIZER)
      (params[:colorizers] || {}).each_pair do |language, colorizer|
        @colorizers[language] = colorizer
      end

      # Determine syntax (HTML or XML)
      syntax = params[:syntax] || :html
      case syntax
      when :html
        klass = Nokogiri::HTML
      when :xml, :xhtml
        klass = Nokogiri::XML
      else
        raise RuntimeError, "unknown syntax: #{syntax.inspect} (expected :html or :xml)"
      end

      # Colorize
      is_fullpage = params.fetch(:is_fullpage) { false }
      doc = is_fullpage ? klass.parse(content, nil, 'UTF-8') : klass.fragment(content)
      selector = params[:outside_pre] ? 'code' : 'pre > code'
      doc.css(selector).each do |element|
        # Get language
        has_class = false
        language = nil
        if element['class']
          # Get language from class
          match = element['class'].match(/(^| )language-([^ ]+)/)
          language = match[2] if match
          has_class = true if language
        else
          # Get language from comment line
          match = element.inner_text.strip.split[0].match(/^#!([^\/][^\n]*)$/)
          language = match[1] if match
          element.content = element.content.sub(/^#!([^\/][^\n]*)$\n/, '') if language
        end

        # Give up if there is no hope left
        next if language.nil?

        # Highlight
        raw = strip(element.inner_text)
        highlighted_code = highlight(raw, language, params)
        element.children = Nokogiri::HTML.fragment(strip(highlighted_code), 'utf-8')

        # Add language-something class
        unless has_class
          klass = element['class'] || ''
          klass << ' ' unless [' ', nil].include?(klass[-1,1])
          klass << "language-#{language}"
          element['class'] = klass
        end

        self.highlight_postprocess(language, element.parent)
      end

      method = "to_#{syntax}".to_sym
      doc.send(method, :encoding => 'UTF-8')
    end

    # Runs the code through [CodeRay](http://coderay.rubychan.de/).
    #
    # @api private
    #
    # @param [String] code The code to colorize
    #
    # @param [String] language The language the code is written in
    #
    # @param [Hash] params Parameters to pass on to CodeRay
    #
    # @return [String] The colorized output
    def coderay(code, language, params={})
      require 'coderay'

      ::CodeRay.scan(code, language).html(params)
    end

    # Returns the input itself, not performing any code highlighting.
    #
    # @param [String] code The code to colorize
    #
    # @param [String] language The language the code is written in (unused)
    #
    # @return [String] The colorized output, which is identical to the input
    #   in this case
    def dummy(code, language, params={})
      code
    end

    # Runs the content through [pygmentize](http://pygments.org/docs/cmdline/),
    # the commandline frontend for [Pygments](http://pygments.org/).
    #
    # @api private
    #
    # @param [String] code The code to colorize
    #
    # @param [String] language The language the code is written in
    #
    # @option params [String, Symbol] :encoding The encoding of the code block
    #
    # @return [String] The colorized output
    def pygmentize(code, language, params={})
      require 'systemu'
      check_availability('pygmentize', '-V')

      params[:encoding] ||= 'utf-8'
      params[:nowrap]   ||= 'True'

      # Build command
      cmd = [ 'pygmentize', '-l', language, '-f', 'html' ]
      cmd << '-O' << params.map { |k,v| "#{k}=#{v}" }.join(',') unless params.empty?

      # Run command
      stdout = StringIO.new
      systemu cmd, 'stdin' => code, 'stdout' => stdout

      # Get result
      stdout.rewind
      stdout.read
    end

    # Runs the content through [Pygments](http://pygments.org/) via
    # [pygments.rb](https://github.com/tmm1/pygments.rb).
    #
    # @api private
    #
    # @param [String] code The code to colorize
    #
    # @param [String] language The language the code is written in
    #
    # @return [String] The colorized output
    def pygmentsrb(code, language, params={})
      require 'pygments'

      args = params.dup
      args[:lexer] ||= language
      args[:options] ||= {}
      args[:options][:encoding] ||= 'utf-8'
      args[:options][:nowrap]   ||= 'True'

      Pygments.highlight(code, args)
    end

    SIMON_HIGHLIGHT_OPT_MAP = {
        :wrap => '-W',
        :include_style => '-I',
        :line_numbers  => '-l',
    }

    # Runs the content through [Highlight](http://www.andre-simon.de/doku/highlight/en/highlight.html).
    #
    # @api private
    #
    # @param [String] code The code to colorize
    #
    # @param [String] language The language the code is written in
    #
    # @option params [String] :style The style to use
    #
    # @return [String] The colorized output
    def simon_highlight(code, language, params={})
      require 'systemu'

      check_availability('highlight', '--version')

      # Build command
      cmd = [ 'highlight', '--syntax', language, '--fragment' ]
      params.each do |key, value|
        if SIMON_HIGHLIGHT_OPT_MAP[key]
          cmd << SIMON_HIGHLIGHT_OPT_MAP[key]
        else
          # TODO allow passing other options
          case key
          when :style
            cmd << '--style' << params[:style]
          end
        end
      end

      # Run command
      stdout = StringIO.new
      systemu cmd, 'stdin' => code, 'stdout' => stdout

      # Get result
      stdout.rewind
      stdout.read
    end

    # Wraps the element in <div class="CodeRay"><div class="code">
    def coderay_postprocess(language, element)
      # Skip if we're a free <code>
      return if element.parent.nil?

      # <div class="code">
      div_inner = Nokogiri::XML::Node.new('div', element.document)
      div_inner['class'] = 'code'
      div_inner.children = element.dup

      # <div class="CodeRay">
      div_outer = Nokogiri::XML::Node.new('div', element.document)
      div_outer['class'] = 'CodeRay'
      div_outer.children = div_inner

      # orig element
      element.swap div_outer
    end

  protected

    KNOWN_COLORIZERS = [ :coderay, :dummy, :pygmentize, :pygmentsrb, :simon_highlight ]

    # Removes the first blank lines and any whitespace at the end.
    def strip(s)
      s.lines.drop_while { |line| line.strip.empty? }.join.rstrip
    end

    def highlight(code, language, params={})
      colorizer = @colorizers[language.to_sym]
      if KNOWN_COLORIZERS.include?(colorizer)
        send(colorizer, code, language, params[colorizer] || {})
      else
        raise RuntimeError, "I don’t know how to highlight code using the “#{colorizer}” colorizer"
      end
    end

    def highlight_postprocess(language, element)
      colorizer = @colorizers[language.to_sym]
      if KNOWN_COLORIZERS.include?(colorizer)
        sym = (colorizer.to_s + '_postprocess').to_sym
        if self.respond_to?(sym)
          self.send(sym, language, element)
        end
      else
        raise RuntimeError, "I don’t know how to highlight code using the “#{colorizer}” colorizer"
      end
    end

    def check_availability(*cmd)
      systemu cmd
      raise "Could not spawn #{cmd.join(' ')}" if $?.exitstatus != 0
    end

  end
end
