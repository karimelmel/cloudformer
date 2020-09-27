class EB_Applications < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the EB Applications
      eb = AWS::ElasticBeanstalk.new(:region => region)
      apps = []
      eb.client.describe_applications().data[:applications].each do |app|
        full_app = app.clone
        full_app.reject!{ |k| k == :date_created }
        full_app.reject!{ |k| k == :date_updated }
        apps << full_app
      end
      all_resources.merge!({:eb_applications => apps})
    rescue => e
      if region.eql?("us-gov-west-1") || region.eql?("cn-north-1") || region.eql?("cn-northwest-1")
        all_errors.merge!({:eb_applications => "Not supported in this region"})
      else
        all_errors.merge!({:eb_applications => e.message})
      end
      all_resources.merge!({:eb_applications => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:application_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    eb_versions = []
    eb_templates = []
    eb_environments = []
    if all_resources[:eb_versions]
      all_resources[:eb_versions].each do |version|
        eb_versions.push(version) if resource[:application_name] == version[:application_name]
      end      
    end
    if all_resources[:eb_templates]
      all_resources[:eb_templates].each do |template|
        eb_templates.push(template) if resource[:application_name] == template[:application_name]
      end      
    end
    if all_resources[:eb_environments]
      all_resources[:eb_environments].each do |env|
        eb_environments.push(env) if resource[:application_name] == env[:application_name]
      end
    end
    return { :eb_templates => eb_templates, :eb_versions => eb_versions, :eb_environments => eb_environments }
  end

  def self.get_resource_attributes(resource)
    return "Application Name: #{resource[:application_name]} \n" +
           "Description: #{resource[:description]}"
  end

  def self.OutputList(resource)
    return {"Application Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = EB_Applications.ResourceName(resource)
    super(@name, "AWS::ElasticBeanstalk::Application")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    #props.merge!({"ApplicationName" => resource[:application_name]}) if resource[:application_name]
    props.merge!({"Description" => resource[:description]}) if resource[:description]
    return @cf_definition.deep_merge({ EB_Applications.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
