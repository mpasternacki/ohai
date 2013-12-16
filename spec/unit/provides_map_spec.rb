#
# Author:: Daniel DeLeo (<dan@opscode.com>)
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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe Ohai::ProvidesMap do

  let(:ohai_system) { Ohai::System.new }
  let(:provides_map) { Ohai::ProvidesMap.new }
  let(:plugin_1) { Ohai::DSL::Plugin.new(ohai_system.data) }
  let(:plugin_2) { Ohai::DSL::Plugin.new(ohai_system.data) }
  let(:plugin_3) { Ohai::DSL::Plugin.new(ohai_system.data) }
  let(:plugin_4) { Ohai::DSL::Plugin.new(ohai_system.data) }

  describe "when looking up providing plugins for a single attribute" do
    describe "when no plugin provides the attribute" do
      it "should raise Ohai::Exceptions::AttributeNotFound error, with inherit = false" do
        expect{ provides_map.find_providers_for(["single"]) }.to raise_error(Ohai::Exceptions::AttributeNotFound, "Cannot find plugin providing attribute 'single'")
      end

      it "should raise Ohai::Exceptions::AttributeNotFound error, with inherit = true" do
        expect{ provides_map.find_providers_for(["single"], true) }.to raise_error(Ohai::Exceptions::AttributeNotFound, "Cannot find plugin providing attribute 'single'")
      end
    end

    describe "when only one plugin provides the attribute" do
      before do
        provides_map.set_providers_for(plugin_1, ["single"])
      end

      it "should return the provider" do
        expect(provides_map.find_providers_for(["single"])).to eq([plugin_1])
      end
    end

    describe "when multiple plugins provide the attribute" do
      before do
        provides_map.set_providers_for(plugin_1, ["single"])
        provides_map.set_providers_for(plugin_2, ["single"])
      end

      it "should return all providers" do
        expect(provides_map.find_providers_for(["single"])).to eq([plugin_1, plugin_2])
      end
    end
  end

  describe "when looking up providing plugins for multiple attributes" do
    describe "when a different plugin provides each attribute" do

      before do
        provides_map.set_providers_for(plugin_1, ["one"])
        provides_map.set_providers_for(plugin_2, ["two"])
      end

      it "should return each provider" do
        expect(provides_map.find_providers_for(["one", "two"])).to eq([plugin_1, plugin_2])
      end
    end

    describe "when one plugin provides both requested attributes" do

      before do
        provides_map.set_providers_for(plugin_1, ["one"])
        provides_map.set_providers_for(plugin_1, ["one_again"])
      end

      it "should return unique providers" do
        expect(provides_map.find_providers_for(["one", "one_again"])).to eq([plugin_1])
      end
    end
  end

  describe "when looking up providers for multi-level attributes" do
    describe "when the full attribute exists in the map" do
      before do
        provides_map.set_providers_for(plugin_1, ["top/middle/bottom"])
      end

      it "should collect the provider" do
        expect(provides_map.find_providers_for(["top/middle/bottom"])).to eq([plugin_1])
      end
    end

    describe "when the full attribute doesn't exist in the map" do
      context "and inherit = false" do
        before do
          provides_map.set_providers_for(plugin_1, ["top/middle"])
        end

        it "should raise Ohai::Exceptions::AttributeNotFound error" do
          expect{ provides_map.find_providers_for(["top/middle/bottom"]) }.to raise_error(Ohai::Exceptions::AttributeNotFound, "Cannot find plugin providing attribute 'top/middle/bottom'")
        end
      end

      context "and inherit = true" do
        before do
          provides_map.set_providers_for(plugin_1, ["top"])
          provides_map.set_providers_for(plugin_2, ["top/middle"])
        end

        it "should not raise error" do
          expect{ provides_map.find_providers_for(["top/middle/bottom"], true) }.not_to raise_error
        end

        it "should return the most specific parent provider" do
          expect(provides_map.find_providers_for(["top/middle/bottom"], true)).to eq([plugin_2])
        end

        it "should raise Ohai::Exceptions::AttributeNotFound error if no parent exists" do
          expect{ provides_map.find_providers_for(["one/two/three"], true) }.to raise_error(Ohai::Exceptions::AttributeNotFound, "Cannot find plugin providing attribute 'one/two/three'")
        end
      end
    end
  end

  describe "when listing all plugins" do
    before(:each) do
      provides_map.set_providers_for(plugin_1, ["one"])
      provides_map.set_providers_for(plugin_2, ["two"])
      provides_map.set_providers_for(plugin_3, ["stub/three"])
      provides_map.set_providers_for(plugin_4, ["foo/bar/four", "also/this/four"])
    end

    it "should find all the plugins providing attributes" do
      all_plugins = provides_map.all_plugins
      expect(all_plugins).to have(4).plugins
      expect(all_plugins).to include(plugin_1)
      expect(all_plugins).to include(plugin_2)
      expect(all_plugins).to include(plugin_3)
      expect(all_plugins).to include(plugin_4)
    end
  end

end

