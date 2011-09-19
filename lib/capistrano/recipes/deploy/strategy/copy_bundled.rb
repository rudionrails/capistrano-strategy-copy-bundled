require 'capistrano/recipes/deploy/strategy/copy'

module Capistrano
  module Deploy
    module Strategy

      class CopyBundled < Copy

        # @overload
        def deploy!
          if copy_cache
            if File.exists?(copy_cache)
              logger.debug "refreshing local cache to revision #{revision} at #{copy_cache}"
              system(source.sync(revision, copy_cache))
            else
              logger.debug "preparing local cache at #{copy_cache}"
              system(source.checkout(revision, copy_cache))
            end

            # Check the return code of last system command and rollback if not 0
            unless $? == 0
              raise Capistrano::Error, "shell command failed with return code #{$?}"
            end

            FileUtils.mkdir_p(destination)

            logger.debug "copying cache to deployment staging area #{destination}"
            Dir.chdir(copy_cache) do
              queue = Dir.glob("*", File::FNM_DOTMATCH)
              while queue.any?
                item = queue.shift
                name = File.basename(item)

                next if name == "." || name == ".."
                next if copy_exclude.any? { |pattern| File.fnmatch(pattern, item) }

                if File.symlink?(item)
                  FileUtils.ln_s(File.readlink(item), File.join(destination, item))
                elsif File.directory?(item)
                  queue += Dir.glob("#{item}/*", File::FNM_DOTMATCH)
                  FileUtils.mkdir(File.join(destination, item))
                else
                  FileUtils.ln(item, File.join(destination, item))
                end
              end
            end
          else
            logger.debug "getting (via #{copy_strategy}) revision #{revision} to #{destination}"
            system(command)

            if copy_exclude.any?
              logger.debug "processing exclusions..."

              copy_exclude.each do |pattern|
                delete_list = Dir.glob(File.join(destination, pattern), File::FNM_DOTMATCH)
                # avoid the /.. trap that deletes the parent directories
                delete_list.delete_if { |dir| dir =~ /\/\.\.$/ }
                FileUtils.rm_rf(delete_list.compact)
              end
            end
          end

          File.open(File.join(destination, "REVISION"), "w") { |f| f.puts(revision) }

          # execute bundler
          bundle!

          logger.trace "compressing #{destination} to #{filename}"
          Dir.chdir(copy_dir) { system(compress(File.basename(destination), File.basename(filename)).join(" ")) }

          distribute!
        ensure
          FileUtils.rm filename rescue nil
          FileUtils.rm_rf destination rescue nil
        end


        private

        def bundle!
          logger.trace "running bundler in #{destination}..."

          bundle_cmd      = configuration[:bundle_cmd]        || "bundle"
          bundle_flags    = configuration[:bundle_flags]      || "--deployment --quiet"
          bundle_dir      = configuration[:bundle_dir]        || File.join('vendor', 'bundle')
          bundle_gemfile  = configuration[:bundle_gemfile]    || File.join("Gemfile")
          bundle_without  = [*(configuration[:bundle_without] || [:development, :test])].compact

          args = ["--gemfile #{File.join(destination, bundle_gemfile)}"]
          args << "--path #{bundle_dir}" unless bundle_dir.to_s.empty?
          args << bundle_flags.to_s
          args << "--without #{bundle_without.join(" ")}" unless bundle_without.empty?

          cmd = "#{bundle_cmd} install #{args.join(' ')}"
          Dir.chdir(destination) do
            defined?( Bundler ) ? with_original_env { system(cmd) } : system(cmd)
          end
        end

        # This method should be built-in to Bundler 1.1+
        def with_original_env
          original_env = ENV.to_hash

          begin
            # clean the ENV from Bundler settings
            ENV.delete( 'RUBYOPT' )
            ENV.keys.each { |k| ENV.delete(k) if k =~ /^bundle_/i }  #remove any BUNDLE_* keys

            yield
          ensure
            ENV.replace( original_env )
          end
        end

      end

    end
  end
end
