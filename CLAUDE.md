# CLAUDE.md — tokenize_attr

## Start here

Before writing any code, read these files in order:

1. **@AGENTS.md** — architecture, design decisions, guardrails, test conventions
2. **@llms/overview.md** — class responsibilities and internal design notes
3. **@llms/usage.md** — common patterns and recipes

---

## Project context

`tokenize_attr` v0.2.0 — declarative secure token generation for ActiveRecord
model attributes. See `@AGENTS.md` for the full design context.

### Key commands

```bash
# Run the full test suite (without Rails/Rake)
~/.local/share/mise/installs/ruby/3.4.6/bin/ruby -Ilib:test test/test_tokenize_attr.rb
~/.local/share/mise/installs/ruby/3.4.6/bin/ruby -Ilib:test test/tokenize_attr/installer_test.rb

# In a Rails app
rails tokenize_attr:install    # create the initializer
rails tokenize_attr:uninstall  # remove the initializer
```
