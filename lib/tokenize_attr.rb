# frozen_string_literal: true

require "active_support"
require "active_support/concern"
require "securerandom"

require_relative "tokenize_attr/version"
require_relative "tokenize_attr/errors"
require_relative "tokenize_attr/tokenizer"
require_relative "tokenize_attr/concern"
require_relative "tokenize_attr/installer"

# TokenizeAttr adds a declarative +tokenize+ class macro to ActiveRecord models.
#
# In a Rails app, run the install task to wire the gem in:
#
#   rails tokenize_attr:install
#
# That creates +config/initializers/tokenize_attr.rb+ which calls
# +ActiveSupport.on_load(:active_record)+ so that every ActiveRecord model
# gets the +tokenize+ macro without an explicit include.
#
# For non-Rails classes that provide +before_create+ and +exists?+, include
# the concern manually:
#
#   class MyModel
#     include TokenizeAttr::Concern
#   end
#
module TokenizeAttr
end

# Register the Railtie when running inside a Rails application.
# The Railtie exposes the `rails tokenize_attr:install` rake task.
require "tokenize_attr/railtie" if defined?(Rails::Railtie)
