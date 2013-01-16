require 'bundler/deployment'
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
          Dir.chdir(copy_cache) { bundle! }
          configuration.trigger('strategy:after:bundle')


          logger.info "compressing repository"
          configuration.trigger('strategy:before:compression')
          compress_repository
          configuration.trigger('strategy:after:compression')


          logger.info "distributing packaged repository"

          configuration.trigger('strategy:before:distrubute')
          distribute!
          configuration.trigger('strategy:after:distrubute')
        ensure
          rollback_changes
        end


        private

        def bundle!
          logger.info "packaging gems for bundler in #{destination}..."
          Bundler.with_clean_env { run "#{configuration.fetch(:bundle_cmd, 'bundle')} package --all" }
        end
      end

    end
  end
end
