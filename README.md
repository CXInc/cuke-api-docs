# cuke-api-docs

A Cucumber formatter that produces API documentation from Cucumber features that have follow a set of rules.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cuke-api-docs'
```

## Usage

Either specify it when you use Cucumber:

```bash
cucumber --format Cucumber::Formatter::ApiDocs
```

Or, add it to your Rakefile:

```ruby
Cucumber::Rake::Task.new(:docs) do |t|
  t.cucumber_opts = "features --format Cucumber::Formatter::ApiDocs"
end
```

So that you can do:

```bash
rake docs
```

Either way, it produces a file named docs.html, which is a self-contained HTML documentation file.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/cuke-api-docs/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
