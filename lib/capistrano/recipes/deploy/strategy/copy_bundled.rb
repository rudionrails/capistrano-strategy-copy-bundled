require 'bundler/deployment'
require 'capistrano'
require 'capistrano/recipes/deploy/strategy/copy'

module Capistrano
  module Deploy
    module Strategy

      class CopyBundled < Copy

        def deploy!
          logger.info "running :copy_bundled strategy"

          copy_cache ? run_copy_cache_strategy : run_copy_strategy

          create_revision_file

          configuration.trigger('strategy:before:bundle')
          #Bundle all gems
          bundle!
          configuration.trigger('strategy:after:bundle')


          logger.info "compressing repository"
          configuration.trigger('strategy:before:compression')
          compress_repository
          configuration.trigger('strategy:after:compression')


          logger.info "distributing packaged repository"

          configuration.trigger('strategy:before:distribute')
          distribute!
          configuration.trigger('strategy:after:distribute')
        ensure
          rollback_changes
        end


        private

        def bundle!
          #Change required variables to use default Bundler task
          capture_original_config(:rake, :bundle_dir, :latest_release)

          logger.info "installing gems to local cache : #{destination}..."

          #Identical to bundler/capistrano.rb but running without callback in post-deploy (unneccesary)
          # but still provides the bundle:install task
          Bundler::Deployment.define_task(configuration, :task, :except => { :no_release => true })
          configuration.set :rake,           lambda { "#{fetch(:bundle_cmd, "bundle")} exec rake" }
          configuration.set :bundle_dir,     configuration.fetch(:bundle_dir, 'vendor/bundle')
          configuration.set :latest_release, destination

          Dir.chdir(destination) do
            configuration.find_and_execute_task('bundle:install')
          end

          #Revert back any altered config variables
          revert_to_original_config!

          logger.info "packaging gems for bundler in #{destination}..."

          Bundler.with_clean_env do
            run_locally "cd #{destination} && #{configuration.fetch(:bundle_cmd, 'bundle')} package --all"
          end
        end

        def capture_original_config(*configuration_keys)
          configuration_keys.inject(@original_configuration = {}) do |result, config_attribute|
            original_value = configuration.fetch(config_attribute, nil)
            result[config_attribute] = original_value if original_value
            result
          end
        end

        def revert_to_original_config!
          return unless @original_configuration
          @original_configuration.each do |config_attribute, original_config_value|
            configuration.set(config_attribute, original_config_value)
          end
        end
      end

    end
  end
end
