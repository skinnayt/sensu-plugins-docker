#! /usr/bin/env ruby
#
#   check-stopped-containers
#
# DESCRIPTION:
#   This is a simple check script for Sensu to check that there is no
#   stopped/restarting contianers matching pattern.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   check-stopped-containers.rb -H /var/run/docker.sock -i prod_
#   CheckDockerContainers OK: No stopped containers found
#
#   check-container.rb -i goof -e blablabla
#   CheckDockerContainers CRITICAL: ["/goofy_moore"] is in status: Exited (0) 2 days ago
#   check-container.rb -i goofy -e moore
#   CheckDockerContainers OK: No stopped containers found
#
# NOTES:
#   default include pattern is ".*"
#   default exclude is none, meaning all is inlcuded
#   warn_cont is not used ATM, but kept for future reference
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-docker/client_helpers'

#
# Check Docker Container
#
class CheckDockerContainers < Sensu::Plugin::Check::CLI
  option :docker_host,
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST',
         description: 'Docker API URI. https://host, https://host:port, http://host, http://host:port, host:port, unix:///path'

  option :include,
         short: '-i CONTAINER',
         long: '--include CONTAINER',
         description: 'Regex of container names to include in query',
         default: '.*'

  option :exclude,
         short: '-e CONTAINER',
         long: '--exclude CONTAINER',
         description: 'Regex of container names to exclude from query',
         default: nil

  # Setup variables
  #
  def initialize
    super
    @crit_cont = []
    @warn_cont = []
  end

  def docker_containers
    @client = DockerApi.new(config[:docker_host])
    path = '/containers/json?all=true'
    response = @client.call(path, false)

    body = parse_json(response)
    body.each do |container|
      next unless container['State'] != 'running'
      container_names = container['Names']
      if check_contains(container_names, config[:include]) && !check_contains(container_names, config[:exclude])
        @crit_cont << "#{container_names} is in status: #{container['Status']}"
      end
    end
  end

  def check_contains(checkarray, pattern)
    unless pattern.nil?
      regex_exclude = Regexp.new(pattern)
      return checkarray.grep(regex_exclude).any?
    end
    false
  end

  # Generate output
  #
  def check_output
    (@crit_cont + @warn_cont).join(', ')
  end

  # Main function
  #
  def run
    docker_containers
    critical check_output unless @crit_cont.empty?
    warning check_output unless @warn_cont.empty?
    ok 'No stopped containers found'
  end
end
