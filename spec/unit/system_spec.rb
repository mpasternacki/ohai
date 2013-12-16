#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Claire McQuin (<claire@opscode.com>)
# Copyright:: Copyright (c) 2008, 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe "Ohai::System" do
  extend IntegrationSupport

  describe "#initialize" do
    before(:each) do
      @ohai = Ohai::System.new
    end

    it "should return an Ohai::System object" do
      @ohai.should be_a_kind_of(Ohai::System)
    end

    it "should set @attributes to a ProvidesMap" do
      @ohai.provides_map.should be_a_kind_of(Ohai::ProvidesMap)
    end

    it "should set @v6_dependency_solver to a Hash" do
      @ohai.v6_dependency_solver.should be_a_kind_of(Hash)
    end
  end

  when_plugins_directory "contains v6 and v7 plugins" do
    with_plugin("zoo.rb", <<EOF)
Ohai.plugin(:Zoo) do
  provides 'seals'
end
EOF

    with_plugin("lake.rb", <<EOF)
provides 'fish'
EOF

    before do
      @ohai = Ohai::System.new
      @original_config = Ohai::Config[:plugin_path]
      Ohai::Config[:plugin_path] = [ path_to(".") ]
    end

    it "load_plugins() should load all the plugins" do
      @ohai.load_plugins
      @ohai.provides_map.map.keys.should include("seals")
      @ohai.v6_dependency_solver.keys.should include("lake.rb")
      Ohai::NamedPlugin.const_get(:Zoo).should == Ohai::NamedPlugin::Zoo
    end
  end

  when_plugins_directory "contains directories inside" do
    with_plugin("repo1/zoo.rb", <<EOF)
Ohai.plugin(:Zoo) do
  provides 'seals'
end
EOF

    with_plugin("repo1/lake.rb", <<EOF)
provides 'fish'
EOF

    with_plugin("repo2/nature.rb", <<EOF)
Ohai.plugin(:Nature) do
  provides 'crabs'
end
EOF

    with_plugin("repo2/mountain.rb", <<EOF)
provides 'bear'
EOF

    before do
      @ohai = Ohai::System.new
      @original_config = Ohai::Config[:plugin_path]
      Ohai::Config[:plugin_path] = [ path_to("repo1"), path_to("repo2") ]
    end

    after do
      Ohai::Config[:plugin_path] = @original_config
    end

    it "load_plugins() should load all the plugins" do
      @ohai.load_plugins
      @ohai.provides_map.map.keys.should include("seals")
      @ohai.provides_map.map.keys.should include("crabs")
      @ohai.v6_dependency_solver.keys.should include("lake.rb")
      @ohai.v6_dependency_solver.keys.should include("mountain.rb")
      Ohai::NamedPlugin.const_get(:Zoo).should == Ohai::NamedPlugin::Zoo
      Ohai::NamedPlugin.const_get(:Nature).should == Ohai::NamedPlugin::Nature
    end
  end

  describe "when running plugins" do
    before do
      @original_config = Ohai::Config[:plugin_path]
    end

    after do
      Ohai::Config[:plugin_path] = @original_config
    end

    before(:each) do
      @ohai = Ohai::System.new
    end

    when_plugins_directory "contains v6 plugins only" do
      with_plugin("zoo.rb", <<EOF)
provides 'zoo'
zoo("animals")
EOF

      with_plugin("park.rb", <<EOF)
provides 'park'
park("plants")
EOF

      it "should collect data from all the plugins" do
        Ohai::Config[:plugin_path] = [ path_to(".") ]
        @ohai.all_plugins
        @ohai.data[:zoo].should == "animals"
        @ohai.data[:park].should == "plants"
      end
    end

    when_plugins_directory "contains v7 plugins only" do
      with_plugin("zoo.rb", <<EOF)
Ohai.plugin(:Zoo) do
  provides 'zoo'

  collect_data(:default) do
    zoo("animals")
  end
end
EOF

      with_plugin("park.rb", <<EOF)
Ohai.plugin(:Park) do
  provides 'park'
  collect_data(:default) do
    park("plants")
  end
end
EOF

      it "should collect data from all the plugins" do
        Ohai::Config[:plugin_path] = [ path_to(".") ]
        @ohai.all_plugins
        @ohai.data[:zoo].should == "animals"
        @ohai.data[:park].should == "plants"
      end

      it "should write an error to Ohai::Log" do
        Ohai::Config[:plugin_path] = [ path_to(".") ]
        @ohai.instance_variable_get("@runner").stub(:run_plugin).and_raise(Ohai::Exceptions::AttributeNotFound)
        Ohai::Log.should_receive(:error).with(/Encountered error while running plugins/)
        expect { @ohai.all_plugins }.to raise_error(Ohai::Exceptions::AttributeNotFound)
      end
    end

    when_plugins_directory "contains v6 plugins that depend on v7 plugins" do
      with_plugin("messages.rb", <<EOF)
require_plugin 'v6message'
require_plugin 'v7message'

provides 'messages'

messages Mash.new
messages[:v6message] = v6message
messages[:v7message] = v7message
EOF

      with_plugin("v6message.rb", <<EOF)
provides 'v6message'
v6message "update me!"
EOF

      with_plugin("v7message.rb", <<EOF)
Ohai.plugin(:V7message) do
  provides 'v7message'

  collect_data(:default) do
    v7message "v7 plugins are awesome!"
  end
end
EOF

      before do
        @ohai = Ohai::System.new
        @original_config = Ohai::Config[:plugin_path]
        Ohai::Config[:plugin_path] = [ path_to(".") ]
      end

      after do
         Ohai::Config[:plugin_path] = @original_config
      end

      it "should collect all data" do
        @ohai.all_plugins
        [:v6message, :v7message, :messages].each do |attribute|
          @ohai.data.should have_key(attribute)
        end

        @ohai.data[:v6message].should eql("update me!")
        @ohai.data[:v7message].should eql("v7 plugins are awesome!")
        [:v6message, :v7message].each do |subattr|
          @ohai.data[:messages].should have_key(subattr)
          @ohai.data[:messages][subattr].should eql(@ohai.data[subattr])
        end
      end
    end
  end

  describe "require_plugin()" do
    when_plugins_directory "contains v6 and v7 plugin with the same name" do
      with_plugin("message.rb", <<EOF)
provides 'message'

message "From Version 6"
EOF

      with_plugin("v7/message.rb", <<EOF)
Ohai.plugin(:Message) do
  provides 'message'

  collect_data(:default) do
    message "From Version 7"
  end
end
EOF

      before do
        @ohai = Ohai::System.new
        @original_config = Ohai::Config[:plugin_path]
        Ohai::Config[:plugin_path] = [ path_to(".") ]
      end

      after do
         Ohai::Config[:plugin_path] = @original_config
      end

      it "version 6 should run" do
        @ohai.load_plugins
        @ohai.require_plugin("message")
        @ohai.data[:message].should eql("From Version 6")
      end
    end

    when_plugins_directory "a v6 plugin that requires a v7 plugin with dependencies" do
      with_plugin("message.rb", <<EOF)
provides 'message'

require_plugin 'v7message'

message Mash.new
message[:v6message] = "Hellos from 6"
message[:copy_message] = v7message
EOF

      with_plugin("v7message.rb", <<EOF)
Ohai.plugin(:V7message) do
  provides 'v7message'
  depends 'zoo'

  collect_data(:default) do
    v7message ("Hellos from 7: " + zoo)
  end
end
EOF

      with_plugin("zoo.rb", <<EOF)
Ohai.plugin(:Zoo) do
  provides 'zoo'

  collect_data(:default) do
    zoo "animals"
  end
end
EOF

      before do
        @ohai = Ohai::System.new
        @original_config = Ohai::Config[:plugin_path]
        Ohai::Config[:plugin_path] = [ path_to(".") ]
      end

      after do
         Ohai::Config[:plugin_path] = @original_config
      end

      it "should collect all the data properly" do
        @ohai.all_plugins
        @ohai.data[:v7message].should == "Hellos from 7: animals"
        @ohai.data[:zoo].should == "animals"
        @ohai.data[:message][:v6message].should == "Hellos from 6"
        @ohai.data[:message][:copy_message].should == "Hellos from 7: animals"
      end
    end

  end
end
