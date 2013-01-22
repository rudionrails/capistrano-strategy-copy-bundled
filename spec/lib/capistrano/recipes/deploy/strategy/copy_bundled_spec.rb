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
                        :trigger => trigger
                   )}
  let(:strategy) { Capistrano::Deploy::Strategy::CopyBundled.new(config) }

  before do
    #Key base class copy commands
    [:create_revision_file,  :compress_repository, :distribute!, :rollback_changes].each do |main_call|
      strategy.should_receive(main_call).once
    end
    logger.should_receive(:info).at_least(3).times
    strategy.stub(:bundle!)
    strategy.stub(:copy_cache => nil, :run_copy_strategy => true)
  end

  context 'with existing copy cache' do
    let(:copy_cache_dir) { '/u/tmp/copy-cache' }
    before do
      strategy.stub!(:copy_cache => copy_cache_dir)
    end

    it 'utilises existing copy cache strategy' do
      strategy.should_receive(:run_copy_cache_strategy).once
      strategy.should_not_receive(:run_copy_strategy)
    end

  end

  context 'with new copy cache' do
    before do
      strategy.stub!(:copy_cache => nil)
    end

    it 'initialises copy strategy' do
      strategy.should_receive(:run_copy_strategy).once
      strategy.should_not_receive(:run_copy_cache_strategy)
    end
  end

  context 'triggers' do

    it 'triggers custom calls during actions' do
      expected_triggers = [ "strategy:before:bundle",
                            "strategy:after:bundle",
                            "strategy:before:compression",
                            "strategy:after:compression",
                            "strategy:before:distribute",
                            "strategy:after:distribute"]

      expected_triggers.each do |trigger_name|
        config.should_receive(:trigger).with(trigger_name).once
      end
    end
  end

  context 'bundle!' do
    let(:copy_cache_dir) { '/u/tmp/copy-cache' }
    let(:custom_bundle_cmd) { 'ANY_VAR=true bundle' }

    before do
      strategy.unstub(:bundle!)

      Bundler::Deployment.should_receive(:define_task).once

      strategy.stub(:run_copy_cache_strategy => true, :run => true)
      Dir.should_receive(:chdir).once.with(destination).and_yield

      config.stub(:fetch)
      config.stub(:find_and_execute_task) { true }
      config.stub(:set) { true }
    end

    it 'runs bundle install before packaging to ensure a local install using the default task' do
      config.stub(:fetch).with(:bundle_dir, 'vendor/bundle') { 'vendor/bundle' }

      config.should_receive(:set).with(:rake, anything).once { true }
      config.should_receive(:set).with(:bundle_dir).once.with(:bundle_dir, 'vendor/bundle') { true }
      config.should_receive(:set).with(:latest_release).once.with(:latest_release, destination) { true }
      config.should_receive(:find_and_execute_task).with('bundle:install').once

      strategy.should_receive(:run).once
    end

    it 'packages ruby gems into destination directory' do
      config.should_receive(:fetch).with(:bundle_cmd, 'bundle' ) { custom_bundle_cmd }
      strategy.should_receive(:run).with("cd #{destination} && ANY_VAR=true bundle package --all").once
    end

    it 'runs within a clean environment' do
      Bundler.should_receive(:with_clean_env).once
    end
  end

  after do
    strategy.stub(:logger) { logger }
    strategy.stub(:destination) { destination }
    strategy.deploy!
  end

end
