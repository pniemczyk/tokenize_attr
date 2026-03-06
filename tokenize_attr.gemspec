# frozen_string_literal: true

require_relative "lib/tokenize_attr/version"

Gem::Specification.new do |spec|
  spec.name = "tokenize_attr"
  spec.version = TokenizeAttr::VERSION
  spec.authors = ["Pawel Niemczyk"]
  spec.email = ["pniemczyk.info@gmail.com"]

  spec.summary = "Declarative secure token generation for ActiveRecord model attributes."
  spec.description = <<~DESC
    tokenize_attr adds a `tokenize` class macro to ActiveRecord models. When no
    prefix is needed it transparently delegates to Rails' built-in
    has_secure_token (Rails 5+). When a prefix is required it installs a
    before_create callback backed by SecureRandom.base58 with configurable
    size, prefix, and retry logic.
  DESC
  spec.homepage = "https://github.com/pniemczyk/tokenize_attr"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.0", "< 9"
end
