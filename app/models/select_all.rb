class Select_All < CF_converter
  
  attr_accessor :name
  
  def self.get_dependencies(resource, all_resources)
    retResources = {}
    if resource && resource.eql?("on")
      template = Template.new()
      all_resources.each do |resource_name, resource_list|
        resList = []
        resource_list.each do |resource_entry|
          resList.push(resource_entry)
        end
        retResources.deep_merge!({resource_name => resList}) if !resList.empty?
      end
    end            
    return retResources
  end

end
