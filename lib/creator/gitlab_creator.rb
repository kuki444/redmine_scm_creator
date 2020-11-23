require 'gitlab'
class GitlabCreator < SCMCreator

    class << self

        def enabled?
            # if options && api
            #     if options['path']
            #         if api['token'] || (api['username'] && api['password'])
            #             if Object.const_defined?(:Gitlab)
            #                 return true
            #             else
            #                 Rails.logger.warn "Ruby Gitlab is not available (required for '#{scm_id}')"
            #             end
            #         else
            #             Rails.logger.warn "missing API credentials (token or username/password) for '#{scm_id}'"
            #         end
            #     else
            #         Rails.logger.warn "missing path for '#{scm_id}'"
            #     end
            # end

            false
        end

        def local?
            false
        end

        # fix the name to avoid errors
        def sanitize(attributes)
            if attributes.has_key?('url')
                url = attributes['url']
                if url !~ %r{\A(#{options['url']}|#{options['ssh']}:)}
                    if url.start_with?(':')
                        url = options['ssh'] + ':' + url
                    elsif url.start_with?('/')
                        url = options['url'] + url
                    elsif url.include?('/')
                        url = options['url'] + '/' + url
                    end
                end
                if url !~ %r{\.git\z}
                    url << '.git' unless url.end_with?('/')
                end
                attributes['url'] = url unless attributes['url'] == url
            end
            attributes
        end

        # path should be the actual URL at this stage
        def access_url(path, repository = nil)
            if path !~ %r{\A(#{options['url']}|#{options['ssh']}:)} &&
               repository.url =~ %r{\A(#{options['url']}|#{options['ssh']}:)}
                repository.url
            else
                path
            end
        end

        # let Repository::gitlab override it
        def access_root_url(path, repository = nil)
            nil
        end

        # let Redmine use the repository URL
        def external_url(repository, regexp = %r{\A(?:http?://|#{options['ssh_usr']}@)})
            repository.url
        end

        # just return the name, as it's remote repository
        def default_path(identifier)
            identifier
        end

        def existing_path(identifier, repository = nil)
            repository.root_url
        end

        def repository_name(path)
            matches = %r{\A(?:.*/)?([^/]+?)(\\.git)?/?\z}.match(path)
            matches ? matches[1] : nil
        end

        def repository_format
            "[#{options['url']}/<username>/]<#{l(:label_repository_format)}>[.git]"
        end

        # to check if repository exists we need username, which is not always available
        def repository_exists?(identifier)
            false
        end

        def create_repository(path, repository = nil)
            false
            # response = client.create(repository_name(path), create_options)
            # if response.is_a?(Sawyer::Resource) && response.key?(:clone_url)
            #     repository.merge_extra_info('extra_created_with_scm' => 1)
            #     if repository && repository.url =~ %r{\A#{options['ssh_usr']}@} && repository.login.blank? && response.key?(:ssh_url)
            #         response[:ssh_url]
            #     else
            #         response[:clone_url]
            #     end
            # else
            #     false
            # end
        # rescue Gitlab::Error => error
        #     Rails.logger.error error.message
        #     false
        end

        def can_register_hook?
            return false if api['register_hook'] == 'forbid'
            Setting.sys_api_enabled?
        end

        def register_hook(repository, login = nil, password = nil)
            return false unless can_register_hook?
            registrar = Gitlab.client(
                endpoint: "#{options['endpoint']}",
                private_token: "#{api['token']}",
                httparty: {
                    headers: { 'Cookie' => 'gitlab_canary=true' }
                }
            )
            gitlab_repository = repository.url.sub(%r{\.git\z}, '').sub(%r{#{options['url']}}, '').sub(%r{\/}, '')
            response = registrar.add_project_hook(
                "#{gitlab_repository}",
                "#{Setting.protocol}://#{Setting.host_name}/sys/fetch_changesets?key=#{Setting.sys_api_key}", #hookurl　http://localhost/redmine/sys/fetch_changesets?key=APIキー&id=
            {
                    :push_events                        => 1,
                    :merge_requests_events              => 1,
                    :tag_push_events                    => 1,
                    :enable_ssl_verification            => 0
                }
            )

            # response = registrar.add_project_hook('grouptest/test',
            #     'http://testhost4/redmine/sys/fetch_changesets?key=1Kz61KMRYmkmiqsZUFGs&id=test',
            #     {
            #         :push_events                        => 1,
            #         :merge_requests_events              => 1,
            #         :tag_push_events                    => 1,
            #         :enable_ssl_verification            => 0
            #     }
            # )
            # puts response
                    
            Rails.logger.info "Registered hook for: #{repository.url}"
            # response.is_a?(Sawyer::Resource)
        # rescue Gitlab::Error => error
        #     Rails.logger.error error.message
        #     false
        end

        def api
            @api ||= options && options['api']
        end

    private

        def create_options
            if options['options'] && options['options'].is_a?(Hash)
                options['options'].symbolize_keys
            else
                {}
            end
        end

    end

end
