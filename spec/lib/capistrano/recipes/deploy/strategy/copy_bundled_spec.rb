require 'spec_helper'

describe Capistrano::Deploy::Strategy::CopyBundled do

  let(:source)      { mock('source') }
  let(:logger)      { mock('logger', :info => true, :debug => true) }
  let(:trigger)     { mock('ConfTrigger') }
  let(:destination) { '/some/where/here/' }
  let(:config) { mock('Config', :application => "captest",
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

    [:copy_cache, :run_copy_strategy, :run_locally, :run].each do |method_call|
      Capistrano::Deploy::Strategy::CopyBundled.any_instance.stub(method_call) { nil }
    end

    # #Key base class copy commands
    [:create_revision_file,  :compress_repository, :distribute!, :rollback_changes].each do |main_call|
      Capistrano::Deploy::Strategy::CopyBundled.any_instance.should_receive(main_call).once
    end
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
      strategy.stub!(:copy_cache => copy_cache_dir)
      strategy.should_receive(:run_copy_cache_strategy).once
      strategy.should_receive(:copy_bundled_cache!).once
    end

    it 'utilises existing copy cache strategy' do
      strategy.should_not_receive(:run_copy_strategy)
      strategy.deploy!
    end

    it 'uses copy cache for bundling gems' do
      config.stub(:fetch).with(:bundle_gemfile, 'Gemfile')    { 'Gemfile' }

      strategy.should_receive(:run_locally).with(/--gemfile #{File.join(copy_cache_dir, 'Gemfile')}/).once
      strategy.should_receive(:run_locally).with(anything) #packaging
      strategy.deploy!
    end
  end

  context 'with no copy cache' do
    before do
      strategy.stub!(:copy_cache => nil)
      strategy.should_receive(:run_copy_strategy).once
      strategy.should_not_receive(:copy_bundled_cache!)
    end

    it 'initialises copy strategy' do
      strategy.should_not_receive(:run_copy_cache_strategy)
      strategy.deploy!
    end

    it 'uses default destination for bundling gems' do
      config.stub(:fetch).with(:bundle_gemfile, 'Gemfile') { 'Gemfile' }
      strategy.stub(:destination) { destination }

      strategy.should_receive(:run_locally).with(/--gemfile #{File.join(destination, 'Gemfile')}/)
      strategy.should_receive(:run_locally).with(anything) #packaging
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
    let(:custom_bundle_cmd) { 'ANY_VAR=true bundle' }

    before do
      strategy.stub(:run_copy_cache_strategy => true, :run => true, :destination => destination)

      config.stub(:fetch).with(:bundle_dir, 'vendor/bundle')  { 'vendor/bundle' }
      config.stub(:fetch).with(:bundle_gemfile, 'Gemfile')    { 'Gemfile' }
      config.stub(:fetch).with(:bundle_cmd, 'bundle' ) { custom_bundle_cmd }
      config.stub(:fetch).with(:bundle_without, [:development, :test]) { [:development, :test, :staging] }

      Bundler.should_receive(:with_clean_env).once.and_yield
    end

    it 'runs bundle install locally and package' do
      strategy.should_receive(:run_locally).with("cd #{destination} && #{custom_bundle_cmd} install --gemfile #{File.join(destination, 'Gemfile')} --path vendor/bundle --without development test staging").once
      strategy.should_receive(:run_locally).with("cd #{destination} && ANY_VAR=true bundle package --all").once
    end

    after do
      strategy.deploy!
    end
  end
end
