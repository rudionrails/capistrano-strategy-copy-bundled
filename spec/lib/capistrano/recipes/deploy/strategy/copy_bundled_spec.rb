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
    #Initialisation
    config.should_receive(:set).with(:rake, anything).once { true }
    Bundler::Deployment.should_receive(:define_task).once

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
    end
  end

  context 'bundle!' do
    let(:custom_bundle_cmd) { 'ANY_VAR=true bundle' }

    before do
      strategy.unstub(:bundle!)
      strategy.stub(:run_copy_cache_strategy => true, :run => true)

      config.stub(:fetch)
      config.stub(:fetch).with(:bundle_gemfile, 'Gemfile')    { 'Gemfile' }
      config.stub(:fetch).with(:bundle_cmd, 'bundle' ) { custom_bundle_cmd }

      Bundler.should_receive(:with_clean_env).once.and_yield
    end

    it 'runs bundle install locally with enforced local variables for standalone deploy' do
      strategy.should_receive(:run_locally).with("cd #{destination} && #{custom_bundle_cmd} install --gemfile #{File.join(destination, 'Gemfile')} --standalone --binstubs").once
    end
  end

  after do
    strategy.stub(:logger) { logger }
    strategy.stub(:destination) { destination }
    strategy.deploy!
  end

end
