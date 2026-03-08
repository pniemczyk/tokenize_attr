# frozen_string_literal: true

module TokenizeAttr
  class Railtie < Rails::Railtie
    railtie_name :tokenize_attr

    # Expose `rails tokenize_attr:install` and `rails tokenize_attr:uninstall`
    # to the host application.
    rake_tasks do
      load File.expand_path("../tasks/tokenize_attr.rake", __dir__)
    end
  end
end
