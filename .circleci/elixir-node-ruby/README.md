# elixir-node-ruby

The `elixir-node-ruby` is a variant of `circleci/elixir` Dockerfiles that adds Ruby on top of `elixir:*-node`, so that `license_finder`, a Ruby Gem, can scan Elixir (`mix`) and Node dependencies in [POA Network](https://github.com/poanetwork) repositories, such as https://github.com/poanetwork/poa-explorer.

## Building

1. `cd .circleci/elixir-node-ruby`
2. `docker build -t poanetwork/elixir:1.6.4-node-ruby .`

## Testing

1. `docker run -it poanetwork/elixir:1.6.4-node-ruby /bin/bash`
2. Run IRB to check for ruby: `irb`
3. In IRB, quit: `quit`
4. Exit container shell: `exit`

## Publishing

1. Login to DockerHub from the Docker CLI: `docker login`
2. Push image `docker push poanetwork/elixir:1.6.4-node-ruby`
