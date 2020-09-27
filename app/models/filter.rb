class Filter < CF_converter

  attr_accessor :name

  def self.get_dependencies(resource, all_resources)
    retResources = {}
    if resource && resource.length > 0 && all_resources && !all_resources.empty?
      template = Template.new()
      all_resources.each do |resource_name, resource_list|
        resList = []
        resource_list.each do |resource_entry|
          if resource_entry[template.resource_metadata[resource_name][:resource_id]].downcase.index(resource.downcase)
            resList.push(resource_entry)
          elsif resource_entry[:tags]
            # tags can be a map or a list (a la autoscaling)
            if resource_entry[:tags].kind_of?(Array)
              resource_entry[:tags].each do |props|
                value = props[:value]
                if value.downcase.include?(resource.downcase)
                  resList.push(resource_entry)
                end
              end
            else
              resource_entry[:tags].each do |key, value|
                if value.downcase.include?(resource.downcase)
                  resList.push(resource_entry)
                end
              end
            end
          elsif resource_entry[:tag_set]
            resource_entry[:tag_set].each do |tag_def|
              tag_def.each do |key, value|
                if value && value.downcase.include?(resource.downcase)
                  resList.push(resource_entry)
                end
              end
            end
          elsif resource_entry[:tag_list]
            resource_entry[:tag_list].each do |tag_def|
              tag_def.each do |key, value|
                if value && value.downcase.include?(resource.downcase)
                  resList.push(resource_entry)
                end
              end
            end
          end
        end
        retResources.deep_merge!({resource_name => resList}) if !resList.empty?
      end
    end
    return retResources
  end


end
