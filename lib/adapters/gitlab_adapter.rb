require_dependency 'redmine/scm/adapters/git_adapter'

module Redmine
    module Scm
        module Adapters
            class GitlabAdapter < GitAdapter
                def clone
                    cmd_args = %w{clone --mirror}
                    cmd_args << url_with_credentials
                    cmd_args << root_url
                    git_cmd(cmd_args)
                    true
                rescue ScmCommandAborted => error
                    Rails.logger.error "gitlab repository cloning failed: #{error.message}"
                    false
                end
                def fetch
                    Dir.chdir(root_url) do
                        cmd_args = %w{fetch --quiet --all --prune}
                        git_cmd(cmd_args)
                    end
                rescue ScmCommandAborted => error
                    Rails.logger.error "commits fetching failed: #{error.message}"
                end
                def api
                    @api ||= ScmConfig && ScmConfig['gitlab']['api']
                end
            private
                def url_with_credentials
                    if @login.present? && @password.present?
                        if url =~ %r{\Ahttp://}
                            url.sub(%r{\Ahttp://}, "http://#{@login}:#{@password}@")
                        elsif url =~ %r{\Ahttps://}
                            url.sub(%r{\Ahttps://}, "https://#{@login}:#{@password}@")
                        else
                            url.sub(%r{\Agit@}, "#{@login}:#{@password}@")
                        end
                    else
                        if url =~ %r{\Ahttp://}
                            url.sub(%r{\Ahttp://}, "http://oauth2:#{api['token']}@")
                        elsif url =~ %r{\Ahttps://}
                            url.sub(%r{\Ahttps://}, "https://oauth2:#{api['token']}@")
                        else
                            url
                        end
                    end
                end
            end
        end
    end
end