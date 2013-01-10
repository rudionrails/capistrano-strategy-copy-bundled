require 'bundler/deployment'
require 'capistrano/recipes/deploy/strategy/copy'

module Capistrano
  module Deploy
    module Strategy

      class CopyBundled < Copy

        def deploy!
          copy_cache ? run_copy_cache_strategy : run_copy_strategy

          create_revision_file

          #Bundle all gems
          bundle!

          compress_repository
          distribute!
        ensure
          rollback_changes
        end


        private

        def bundle!
          logger.trace "running bundler in #{destination}..."

          #Change required variables to use Bundler task
          capture_original_config(:latest_release, :bundle_dir)

          #Identical to bundler/capistrano.rb but running without callback in post-deploy
          Bundler::Deployment.define_task(configuration, :task, :except => { :no_release => true })
          configuration.set :rake,           lambda { "#{fetch(:bundle_cmd, "bundle")} exec rake" }
          configuration.set :bundle_dir,     configuration.fetch(:bundle_dir, File.join(copy_cache, 'vendor/bundle'))
          configuration.set :latest_release, copy_cache
          configuration.find_and_execute_task('bundle:install')

          #Revert back key config variables
          revert_to_original_config!

          exit
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
