# frozen_string_literal: true

require "active_support"
require "active_support/concern"
require "securerandom"

require_relative "tokenize_attr/version"
require_relative "tokenize_attr/errors"
require_relative "tokenize_attr/tokenizer"
require_relative "tokenize_attr/concern"

module TokenizeAttr
  # When loaded inside a Rails application, auto-include the concern into
  # ActiveRecord::Base so every model gains the +tokenize+ macro without
  # an explicit include. If ActiveRecord is already loaded (e.g. in tests
  # without a full Rails boot) the block executes immediately.
  ActiveSupport.on_load(:active_record) { include TokenizeAttr::Concern }
end
