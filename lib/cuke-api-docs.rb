require "cuke-api-docs/version"
require "cucumber/formatter/api_docs"

# Extend Cucumber's builtin formats, so that this
# formatter can be used with --format api-docs
require 'cucumber/cli/main'

Cucumber::Cli::Options::BUILTIN_FORMATS["api-docs"] = [
  "Cucumber::Formatter::ApiDocs",
  "Turns specially formatted cucumber features into API documentation"
]
