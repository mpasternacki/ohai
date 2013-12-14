#
# Author:: Claire McQuin (<claire@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License. You may
# obtain a copy of the license at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either expressed or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License
#

require 'ohai/dsl'

module Ohai
  class Runner

    # safe_run: set to true if this runner will run plugins in
    # safe-mode. default false.
    def initialize(controller, safe_run = false)
      @provides_map = controller.provides_map
      @safe_run = safe_run
    end

    # runs this plugin and any un-run dependencies. if force is set to
    # true, then this plugin and its dependencies will be run even if
    # they have been run before.
    def run_plugin(plugin, force = false)
      unless plugin.kind_of?(Ohai::DSL::Plugin)
        raise ArgumentError, "Invalid plugin #{plugin} (must be an Ohai::DSL::Plugin or subclass)"
      end
      visited = [plugin]
      while !visited.empty?
        next_plugin = visited.pop

        next if next_plugin.has_run? unless force

        if visited.include?(next_plugin)
          raise Ohai::Exceptions::DependencyCycle, "Dependency cycle detected. Please refer to the following plugins: #{get_cycle(visited, p).join(", ") }"
        end

        dependency_providers = fetch_plugins(next_plugin.dependencies)
        dependency_providers.delete_if { |dep_plugin| (!force && dep_plugin.has_run?) || dep_plugin.eql?(next_plugin) }

        if dependency_providers.empty?
          @safe_run ? next_plugin.safe_run : next_plugin.run
        else
          visited << next_plugin << dependency_providers.first
        end
      end
    end

    # returns a list of plugins which provide the given attributes
    def fetch_plugins(attributes)
      plugins = []
      # subattribute_regex matches the lowest subattribute of any
      # given attribute. if the attribute is 'attr/sub1/sub2', then
      # subattribute_regex matches '/sub2'. if the attribute is 'attr'
      # then subattribute_regex matches nothing.
      subattribute_regex = Regexp.new("/[^/]+$")
      attributes.each do |attribute|
        partial_attribute = attribute
        # look for providers until 1) we find some, or 2) we've
        # exhaused our search (the highest-level of the attribute
        # doesn't return any results
        while (found_providers = safe_find_providers_for(partial_attribute)).empty?
          md = subattribute_regex.match(partial_attribute)
          # since md doesn't match the highest-level attribute, if md
          # is nil, then we can't look any higher. this attribute
          # really does not exist.
          raise Ohai::Exceptions::AttributeNotFound, "Cannot find plugin providing #{attribute}" unless md
          # remove the lowest-level subattribute and look again
          # don't use chomp! affects attribute, too.
          partial_attribute = partial_attribute.chomp(md[0])
        end
        plugins << found_providers
        plugins.flatten!
      end
      plugins.uniq
    end

    # "safely" finds providers for a single attribute. by "safe", if
    # there are no plugins providing the attribute, return an empty
    # array to indicate this (don't raise
    # Ohai::Exceptions::AttributeNotFound error)
    def safe_find_providers_for(attribute)
      begin
        @provides_map.find_providers_for([attribute])
      rescue Ohai::Exceptions::AttributeNotFound
        return []
      end
    end

    # given a list of plugins and the first plugin in the cycle,
    # returns the list of plugin source files responsible for the
    # cycle. does not include plugins that aren't a part of the cycle
    def get_cycle(plugins, cycle_start)
      cycle = plugins.drop_while { |plugin| !plugin.eql?(cycle_start) }
      names = []
      cycle.each { |plugin| names << plugin.name }
      names
    end

  end
end
