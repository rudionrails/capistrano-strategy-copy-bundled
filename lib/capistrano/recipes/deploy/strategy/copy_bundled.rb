require 'bundler/deployment'
require 'capistrano/recipes/deploy/strategy/copy'

# Capistrano::Configuration.instance(:must_exist).load do
#   #before "deploy:finalize_update", "bundle:install"
#   before "deploy:finalize_update", "strategy:bundle", "strategy:distribute"
#   namespace :strategy do
#     task :bundle do
#       puts "YO"
#     end

#     task :distribute do
#       puts "Distributing"
#     end
#   end
# end

module Capistrano
  module Deploy
    module Strategy

      class CopyBundled < Copy

        def deploy!
          logger.trace "running :copy_bundled strategy"

          copy_cache ? run_copy_cache_strategy : run_copy_strategy

          create_revision_file

          configuration.trigger('strategy:before:bundle')
          #Bundle all gems
          bundle!
          configuration.trigger('strategy:after:bundle')

          logger.trace "compressing repository"
          compress_repository


          logger.trace "distributing package"

          configuration.trigger('strategy:before:distrubute')
          distribute!
          configuration.trigger('strategy:after:distrubute')
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
