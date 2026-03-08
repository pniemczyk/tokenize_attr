# AGENTS.md — tokenize_attr

This file is the primary context document for AI agents and LLMs working on
this gem. Read it fully before making any changes.

---

## What this gem does

`tokenize_attr` provides a single public API — the `tokenize` class macro —
available on any ActiveRecord model (or any class with `before_create` and
a class-level `exists?` method).

**When no prefix and no generator are given** and the including class responds
to `has_secure_token` (Rails 5+), `tokenize` delegates entirely to that
built-in. This gives Rails-idiomatic token generation for free and avoids
duplicating Rails core behaviour.

**When a prefix or a custom generator is given** (or `has_secure_token` is
unavailable), `tokenize` installs a `before_create` callback that:

1. Skips if the attribute already has a value (`present?` check).
2. Calls `generator.call(size)` if a generator was provided, otherwise calls
   `SecureRandom.base58(size)` to produce the random portion.
3. Prepends `prefix-` to the random portion when `prefix:` is set.
4. Checks uniqueness via `self.class.exists?(attribute => candidate)`.
5. Retries up to `retries` times (default 3).
6. Raises `TokenizeAttr::RetryExceededError` if all retries are exhausted.

**Rails integration** is wired via an installer task. Running
`rails tokenize_attr:install` generates
`config/initializers/tokenize_attr.rb` which calls
`ActiveSupport.on_load(:active_record)` to include `TokenizeAttr::Concern`
into every `ActiveRecord::Base` subclass automatically.

---

## File map

| File                                   | Role                                                              |
|----------------------------------------|-------------------------------------------------------------------|
| `lib/tokenize_attr.rb`                 | Entry point. Requires sub-files; loads Railtie when in Rails.     |
| `lib/tokenize_attr/version.rb`         | `TokenizeAttr::VERSION` constant.                                 |
| `lib/tokenize_attr/errors.rb`          | `TokenizeAttr::Error` and `TokenizeAttr::RetryExceededError`.     |
| `lib/tokenize_attr/tokenizer.rb`       | `TokenizeAttr::Tokenizer` — all token-generation logic (private). |
| `lib/tokenize_attr/concern.rb`         | `TokenizeAttr::Concern` — thin concern with the `tokenize` macro. |
| `lib/tokenize_attr/installer.rb`       | `TokenizeAttr::Installer` — writes/removes the Rails initializer. |
| `lib/tokenize_attr/railtie.rb`         | `TokenizeAttr::Railtie` — registers rake tasks in Rails.          |
| `lib/tasks/tokenize_attr.rake`         | `tokenize_attr:install` and `tokenize_attr:uninstall` rake tasks. |
| `test/test_helper.rb`                  | In-memory SQLite setup; simulates the installed initializer.      |
| `test/test_tokenize_attr.rb`           | Full integration test suite.                                      |
| `test/tokenize_attr/installer_test.rb` | Unit tests for `TokenizeAttr::Installer`.                         |
| `sig/tokenize_attr.rbs`                | RBS type signatures.                                              |
| `llms/overview.md`                     | Internal design notes for LLMs.                                   |
| `llms/usage.md`                        | Common usage patterns for LLMs.                                   |

---

## Design decisions

### Why delegate to `has_secure_token`?
Rails' `has_secure_token` is battle-tested and available in every Rails 5+
app. Delegating when possible avoids reimplementing core Rails behaviour and
ensures compatibility with any `regenerate_<attr>` helpers Rails adds.

### Why `SecureRandom.base58`?
Base58 produces URL-safe strings without ambiguous characters (no `0`, `O`,
`I`, `l`). Combined with a meaningful prefix it creates tokens that are both
human-readable and collision-resistant.

### Why configurable `retries` with an explicit error?
Silent token-generation failures are worse than loud ones. A configurable
retry budget with an explicit error makes the failure mode observable and
actionable. The default of 3 is generous given the token space size.

### Why is `retries` ignored when delegating to `has_secure_token`?
Rails does not perform uniqueness checks in `has_secure_token`; it relies on
the DB constraint and the astronomically large token space. Retrying there
would be misleading. Document the discrepancy clearly.

### Why does a generator always bypass `has_secure_token`?
The user has explicitly chosen a custom algorithm. Delegating to
`has_secure_token` anyway would silently ignore the generator, which is
surprising. Presence of a generator always routes through the callback path.

### Why is `TokenizeAttr::Tokenizer` a separate class?
Keeping all generation helpers in `Tokenizer` rather than in the
`class_methods` block of `Concern` ensures that none of those methods are
mixed into the user's model class. This eliminates any risk of method-name
collisions for models that happen to define methods with similar names.
`Concern` only exposes the single public `tokenize` macro.

### Why use an installer task instead of an inline `on_load`?
The installer pattern (also used by `inquiry_attrs`) gives host applications
explicit, auditable control over when the concern is included. The generated
initializer is checked into the host app's source control, making the
integration visible and easy to remove or customise. An inline `on_load` in
the gem's main file would silently include the concern on every `require`,
which is less predictable in non-Rails contexts.

---

## Guardrails

- **Do not change the `tokenize` signature** without a major version bump.
- **Do not add a hard runtime dependency on `activerecord`**. Only
  `activesupport` is required. AR's `before_create` and `exists?` are
  consumed via duck typing.
- **Keep tests without the `rails` gem**. The suite uses bare `activerecord`
  + in-memory SQLite — no full Rails boot.
- **Do not swallow `RetryExceededError`**. It is intentionally raised so
  callers can handle it.
- **Keep `TokenizeAttr::Tokenizer` methods private** (except `apply`). The
  class is `@api private`; only `apply` is the stable internal contract.
- **`TokenizeAttr::Installer` must not depend on Rake or Rails**. All
  file-system logic lives in plain Ruby so it can be unit-tested in isolation.

---

## Test conventions

- One `Minitest::Test` subclass per behavioural group.
- `setup` truncates the shared `records` table via a raw SQL DELETE.
- Collision scenarios are tested using **anonymous subclasses** that override
  `exists?` directly (e.g. `Class.new(ApiClient) { def self.exists?(*) = true }`).
  Do **not** use minitest's `stub` on AR model classes — ActiveRecord 8.x
  `method_missing` intercepts `stub` before minitest can install it.
- Model classes share `self.table_name = "records"` so the schema stays flat.
- All column names used by test models must exist in the `records` table
  defined in `test/test_helper.rb`.
- `test/test_helper.rb` simulates the initializer generated by
  `rails tokenize_attr:install` by calling `ActiveSupport.on_load(:active_record)`
  manually — no full Rails boot is required.
- Installer tests in `test/tokenize_attr/installer_test.rb` use `Dir.mktmpdir`
  to create a throwaway filesystem tree; no Rails environment is needed.
