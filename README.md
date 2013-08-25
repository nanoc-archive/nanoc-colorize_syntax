[![Build Status](https://travis-ci.org/nanoc/nanoc-colorize_syntax.png)](https://travis-ci.org/nanoc/nanoc-colorize_syntax)
[![Code Climate](https://codeclimate.com/github/nanoc/nanoc-colorize_syntax.png)](https://codeclimate.com/github/nanoc/nanoc-colorize_syntax)
[![Coverage Status](https://coveralls.io/repos/nanoc/nanoc-colorize_syntax/badge.png?branch=master)](https://coveralls.io/r/nanoc/nanoc-colorize_syntax)

# nanoc-colorize_syntax

This provides a syntax colorising filter for [nanoc](http://nanoc.ws).

## Installation

`gem install nanoc-colorize_syntax`

You will also need to install the dependencies for the individual colorisers. For example, to use `:coderay`, you will need to `gem install coderay`.

## Usage

Code blocks should be enclosed in `pre` elements that contain a `code` element. The code element should have an indication of the language the code is in. There are two possible ways of adding such an indication:

1. A HTML class starting with `language-` and followed by the code language, as specified by HTML5. For example, `<code class="language-ruby">`.

2. A comment on the very first line of the code block in the format `#!language` where `language` is the language the code is in. For example, `#!ruby`.

Here is an example of using a class to indicate type of code be highlighted:

```html
<pre><code class="language-ruby">
def foo
  "asdf"
end
</code></pre>
```

Here is an example of using a comment to indicate type of code be highlighted:

```html
<pre><code>
#!ruby
def foo
  "asdf"
end
</code></pre>
```

Options for individual colorizers will be taken from the {#run} options’ value for the given colorizer. For example, if the filter is invoked with a `:coderay => coderay_options_hash` option, the `coderay_options_hash` hash will be passed to the CodeRay colorizer. For example, the following will pass `{ :line_numbers => :list }` to CodeRay:

```ruby
filter :colorize_syntax,
       :colorizers => { :ruby => :coderay },
       :coderay    => { :line_numbers => :list }
```

Currently, the following colorizers are supported:

* `:coderay` for [Coderay](http://coderay.rubychan.de/)
* `:pygmentize` for [pygmentize](http://pygments.org/docs/cmdline/), the commandline frontend for [Pygments](http://pygments.org/)
* `:pygmentsrb` for [pygments.rb](https://github.com/tmm1/pygments.rb), a Ruby interface for [Pygments](http://pygments.org/)
* `:simon_highlight` for [Highlight](http://www.andre-simon.de/doku/highlight/en/highlight.html)

Additional colorizer implementations are welcome!

Options:

* `:default_colorizer` (default `:coderay`): The default colorizer, i.e. the colorizer that will be used when the colorizer is not overriden for a specific language.

* `:syntax` (default `:html`): The syntax to use, which can be `:html`, `:xml` or `:xhtml`, the latter two being the same.

* `:colorizers` (default `{}`): A hash containing a mapping of programming languages (symbols, not strings) onto colorizers (symbols).

* `:outside_pre` (default `false`): `true` if the colorizer should be applied on `code` elements outside `pre` elements, false if only `code` elements inside` pre` elements should be colorized.

* `:is_fullpage` (default false): Whether to treat the input as a full HTML page or a page fragment. When true, HTML boilerplate such as the doctype, `html`, `head` and `body` elements will be added.
