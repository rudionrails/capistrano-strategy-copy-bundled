require 'bundler/deployment'
require 'capistrano'
require 'capistrano/recipes/deploy/strategy/copy'

module Capistrano
  module Deploy
    module Strategy

      class CopyBundled < Copy

        def initialize(config = {})
          super(config)

          #Initialize with default bundler/capistrano tasks (bundle:install)
          configuration.set :rake, lambda { "#{configuration.fetch(:bundle_cmd, "bundle")} exec rake" } unless configuration.exists?(:rake)
          Bundler::Deployment.define_task(configuration, :task, :except => { :no_release => true })
        end

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

        def bundle_cache_dir
          @bundle_cache_dir ||= configuration.fetch(:bundle_cache, false)
        end

        def bundle!
          bundle_cmd        = configuration.fetch(:bundle_cmd, "bundle")
          bundle_gemfile    = configuration.fetch(:bundle_gemfile, "Gemfile")
          bundle_dir        = configuration.fetch(:bundle_dir, 'vendor/bundle')
          bundle_flags      = configuration.fetch(:bundle_flags, "--deployment --quiet")
          bundle_without    = [*configuration.fetch(:bundle_without, [:development, :test])].compact
          bundle_package    = configuration.fetch(:bundle_package, false)

          args = ["--gemfile '#{File.join(destination, bundle_gemfile)}'"]
          args << "--path #{bundle_dir}" unless bundle_dir.to_s.empty?
          args << bundle_flags.to_s unless bundle_flags.to_s.empty?
          args << "--without #{bundle_without.join(" ")}" unless bundle_without.empty?

          Bundler.with_clean_env do
            if bundle_cache_dir
              execute "symlinking bundle cache : #{bundle_cache_dir} -> #{bundle_dir}..." do
                create_dir    = "mkdir -p #{bundle_cache_dir}"
                symlink_cache = "ln -s #{bundle_cache_dir} #{File.join(destination, bundle_dir)}"
                Dir.chdir(destination) { system("#{create_dir} && #{symlink_cache}") }
              end
            end

            execute "installing gems to local cache : #{destination}..." do
              Dir.chdir(destination) { system("#{bundle_cmd} install #{args.join(' ').strip}") }
            end

            if bundle_package
              execute "packaging gems for bundler in #{destination}..." do
                Dir.chdir(destination) { system("#{bundle_cmd} package --all") }
              end
            end
          end

          def compression
            result = super

            if bundle_cache_dir
              case result.extension
              when "tar.gz", "tar.bz2"
                # Append -h to compression to dereference symbolic links
                # in tarball compression
                result.compress_command = [
                  result.compress_command[0], result.compress_command[1] << h
                ]
              end
            end

            result
          end
        end
      end

    end
  end
end
