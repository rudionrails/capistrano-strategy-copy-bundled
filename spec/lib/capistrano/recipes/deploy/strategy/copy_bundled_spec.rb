require 'spec_helper'

describe Capistrano::Deploy::Strategy::CopyBundled do

  let(:source)        { double('source') }
  let(:logger)        { double('logger', :info => true, :debug => true) }
  let(:trigger)       { double('ConfTrigger') }
  let(:destination)   { '/some/where/here/' }
  let(:bundle_cache)  { false }
  let(:bundle_package){ false }
  let(:config) { double('Config', :application => "captest",
                      :releases_path => "/u/apps/test/releases",
                      :release_path => "/u/apps/test/releases/1234567890",
                      :real_revision => "154",
                      :trigger => trigger,
                      :exists? => false,
                      :set => true,
                      :[] => 'hello',
                      :logger => logger,
                      :fetch => ''
                      )}
  let(:strategy) { Capistrano::Deploy::Strategy::CopyBundled.new(config) }

  before do
    #Initialisation
    Bundler::Deployment.should_receive(:define_task).once

    [ :copy_cache, :run_copy_strategy, :run_locally, :run ].each do |method_call|
      Capistrano::Deploy::Strategy::CopyBundled.any_instance.stub(method_call) { nil }
    end

    # #Key base class copy commands
    [:create_revision_file,  :compress_repository, :distribute!, :rollback_changes].each do |main_call|
      Capistrano::Deploy::Strategy::CopyBundled.any_instance.should_receive(main_call).once
    end

    Dir.stub(:chdir)
  end

  context 'rake definition' do
    it 'sets rake command by default' do
      config.stub(:exists?).with(:rake) { false }
      config.should_receive(:set).with(:rake, anything).once { true }
    end

    it 'uses any existing rake command if already exists' do
      config.stub(:exists?).with(:rake) { true }
      config.should_not_receive(:set).with(:rake, anything)
    end

    after do
      Capistrano::Deploy::Strategy::CopyBundled.new(config).deploy!
    end
  end

  context 'with existing copy cache' do
    let(:copy_cache_dir) { '/u/tmp/copy-cache' }
    before do
      strategy.stub(:copy_cache => copy_cache_dir)
    end

    it 'utilises existing copy cache strategy' do
      strategy.should_receive(:run_copy_cache_strategy).once
      strategy.should_not_receive(:run_copy_strategy)
      strategy.deploy!
    end
  end

  context 'with new copy cache' do
    before do
      strategy.stub(:copy_cache => nil)
    end

    it 'initialises copy strategy' do
      strategy.should_receive(:run_copy_strategy).once
      strategy.should_not_receive(:run_copy_cache_strategy)
      strategy.deploy!
    end
  end

  context 'triggers' do
    it 'custom calls during actions' do
      expected_triggers = [ "strategy:before:bundle",
                            "strategy:after:bundle",
                            "strategy:before:compression",
                            "strategy:after:compression",
                            "strategy:before:distribute",
                            "strategy:after:distribute"]

      expected_triggers.each do |trigger_name|
        config.should_receive(:trigger).with(trigger_name).once
      end
      strategy.deploy!
    end
  end

  context 'bundle!' do
    let(:custom_bundle_cmd)         { 'ANY_VAR=true bundle' }
    let(:expected_install_command)  do
      "#{custom_bundle_cmd} install --gemfile '#{File.join(destination, 'Gemfile')}' --path vendor/bundle --without development test staging"
    end

    before do
      strategy.stub(:run_copy_cache_strategy => true, :run => true, :destination => destination)

      config.stub(:fetch).with(:bundle_dir, 'vendor/bundle')  { 'vendor/bundle' }
      config.stub(:fetch).with(:bundle_gemfile, 'Gemfile')    { 'Gemfile' }
      config.stub(:fetch).with(:bundle_cmd, 'bundle' ) { custom_bundle_cmd }
      config.stub(:fetch).with(:bundle_without, [:development, :test]) { [:development, :test, :staging] }
      config.stub(:fetch).with(:bundle_cache, false) { bundle_cache }
      config.stub(:fetch).with(:bundle_package, false) { bundle_package }

      Bundler.should_receive(:with_clean_env).once.and_yield
    end

    context "by default" do
      it 'runs bundle install only' do
        Dir.should_receive(:chdir).with(destination).once.and_yield
        strategy.should_receive(:system).with(expected_install_command).once
      end
    end

    context "with bundle cache" do
      let(:bundle_cache) { '/tmp/bundler-cache' }
      it 'runs bundle install with cache directory' do
        Dir.should_receive(:chdir).with(destination).twice.and_yield
        strategy.should_receive(:system).with("mkdir -p #{bundle_cache} && ln -s #{bundle_cache} #{destination}vendor/bundle").once
        strategy.should_receive(:system).with(expected_install_command).once
      end
    end

    context "with bundle package" do
      let(:bundle_package) { true }

      it 'runs bundle install with package' do
        Dir.should_receive(:chdir).with(destination).twice.and_yield
        strategy.should_receive(:system).with(expected_install_command).once
        strategy.should_receive(:system).with("ANY_VAR=true bundle package --all").once
      end
    end

    context "with both package and cache" do
      let(:bundle_package) { true }
      let(:bundle_cache) { true }

      it 'runs bundle install and all options' do
        Dir.should_receive(:chdir).with(destination).exactly(3).times.and_yield
        strategy.should_receive(:system).exactly(3).times
      end
    end

    after do
      strategy.deploy!
    end
  end
end
