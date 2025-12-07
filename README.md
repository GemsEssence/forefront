# Forefront
Short description and motivation.

## Usage
How to use my plugin.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "forefront"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install forefront
```

## Run

```bash
bundle install
rails g forefront:install
rails db:migrate
```

Mount the engine (generator does this automatically):

```ruby
# config/routes.rb
mount Forefront::Engine, at: "/forefront"
```

## Configure
you can override the authentication (optional) in `config/initializers/forefront.rb`.
```ruby
Forefront.setup do |config|
  config.user_class          = "User"
  config.authenticate_with   = :authenticate_user!
  config.current_user_method = :current_user
end
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
