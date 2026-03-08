# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-07

### Added
- `TokenizeAttr::Installer` class — manages creation and removal of the
  Rails initializer (`config/initializers/tokenize_attr.rb`) that wires the
  gem into `ActiveRecord::Base` via `ActiveSupport.on_load(:active_record)`.
- `TokenizeAttr::Railtie` — registers `rails tokenize_attr:install` and
  `rails tokenize_attr:uninstall` rake tasks in Rails applications.
- `lib/tasks/tokenize_attr.rake` — the rake task implementations.
- `test/tokenize_attr/installer_test.rb` — full unit-test coverage for the
  installer (create, skip-if-exists, uninstall, content validity).

### Changed
- `lib/tokenize_attr.rb` no longer calls `ActiveSupport.on_load` directly.
  The `on_load` hook is now installed by the generated initializer
  (`rails tokenize_attr:install`) rather than at require-time. This mirrors
  the pattern used by `inquiry_attrs` and gives host applications explicit
  control over when and whether the concern is included.
- Gem renamed from `token_attr` to `tokenize_attr`; module namespace renamed
  from `TokenAttr` to `TokenizeAttr` across all files.
- `TokenAttr::Tokenizer` extracted as a dedicated private class so that no
  internal helper methods are mixed into model classes.

## [0.1.0] - 2026-02-01

### Added
- Initial release.
- `tokenize` class macro for ActiveRecord models.
- Transparent delegation to `has_secure_token` (Rails 5+) when no prefix or
  custom generator is provided.
- Custom `before_create` callback backed by `SecureRandom.base58` when a
  prefix is required or `has_secure_token` is unavailable.
- `size:` option (default 64) controlling token length.
- `prefix:` option prepending `"prefix-<token>"`.
- `retries:` option (default 3) with `TokenizeAttr::RetryExceededError` raised
  when all attempts are exhausted.
- Custom generator support: proc as second positional argument, block, or
  method reference via `&`.

[Unreleased]: https://github.com/pniemczyk/tokenize_attr/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/pniemczyk/tokenize_attr/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/pniemczyk/tokenize_attr/releases/tag/v0.1.0
