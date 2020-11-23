require_dependency File.expand_path('../../../../lib/adapters/gitlab_adapter', __FILE__)

class Repository::Gitlab < Repository::Git
    validates_format_of :url, :with => %r{\A(#{GitlabCreator.options['url']}/|#{GitlabCreator.options['ssh']}:)[a-z0-9\-_]+/[a-z0-9\-_]+\.git\z}i, :allow_blank => true

    before_save :set_local_url, :register_hook
    before_create :clone_repository
    safe_attributes 'register_hook'

    def self.human_attribute_name(attribute, *args)
        attribute_name = attribute.to_s
        if attribute_name == 'url'
            attribute_name = 'gitlab_url'
        end
        super(attribute_name, *args)
    end

    def self.scm_adapter_class
        Redmine::Scm::Adapters::GitlabAdapter
    end

    def self.scm_name
        'Gitlab'
    end

    def self.scm_available
        super && GitlabCreator.options && GitlabCreator.options['path']
    end

    def extra_created_with_scm
        extra_boolean_attribute('extra_created_with_scm')
    end

    def extra_register_hook
        if new_record? && (extra_info.nil? || extra_info['extra_register_hook'].nil?)
            default_value = GitlabCreator.api['register_hook']
            return true if default_value == 'force'
            if default_value.is_a?(TrueClass) || default_value.is_a?(FalseClass)
                return default_value
            end
        end
        extra_boolean_attribute('extra_register_hook')
    end

    def register_hook=(arg)
        merge_extra_info "extra_register_hook" => arg
    end

    def extra_hook_registered
        extra_boolean_attribute('extra_hook_registered')
    end

    def extra_report_last_commit
        true
    end

    def fetch_changesets
        if File.directory?(root_url)
            Rails.logger.info "Fetching updates for #{root_url}"
            scm.fetch
        end
        super
    end

    def clear_extra_info_of_changesets
    end

protected

    def extra_boolean_attribute(name)
        return false if extra_info.nil?
        value = extra_info[name]
        return false if value.nil?
        value.to_s != '0'
    end

    def set_local_url
        if new_record? && url.present? && root_url.blank? && GitlabCreator.options && GitlabCreator.options['path']
            path = url.sub(%r{\A(#{GitlabCreator.options['url']}|#{GitlabCreator.options['ssh_address']})[:/]}, '')
            if Redmine::Platform.mswin?
                self.root_url = "#{GitlabCreator.options['path']}\\#{path.gsub(%r{/}, '\\')}"
            else
                self.root_url = "#{GitlabCreator.options['path']}/#{path}"
            end
        end
    end

    def register_hook
        return if extra_hook_registered
        if (new_record? && GitlabCreator.api['register_hook'] == 'force') || extra_register_hook
            if extra_created_with_scm
                result = GitlabCreator.register_hook(self)
            else
                result = GitlabCreator.register_hook(self, login, password)
            end
            if result
                self.merge_extra_info('extra_hook_registered' => 1)
                self.merge_extra_info('extra_register_hook'   => 1) unless extra_register_hook
            else
                self.merge_extra_info('extra_register_hook' => 0)
            end
        end
    end

    def clone_repository
        if File.directory?(GitlabCreator.options['path'])
            path = File.dirname(root_url)
            Dir.mkdir(path) unless File.directory?(path)
            Rails.logger.info "Cloning #{url} to #{root_url}"
            unless scm.clone
                errors.add(:base, :scm_repository_cloning_failed)
                false
            end
        else
            Rails.logger.warn "Can't find directory: #{GitlabCreator.options['path']} ( path for #{scm_name} )"
            errors.add(:base, :scm_repository_cloning_failed)
            false
        end
    end
end
