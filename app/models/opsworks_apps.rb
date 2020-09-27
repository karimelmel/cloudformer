class OPSWORKS_Apps < CF_converter
  
  attr_accessor :name
  @@resource_id = 1
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Opsworks Applications
      opsworks = AWS::OpsWorks.new()
      apps = []
      all_resources[:opsworks_stacks].each do |stack|
        opsworks.client.describe_apps({:stack_id => stack[:stack_id]}).data[:apps].each do |app|
          app[:stack_name] = stack[:name]
          app[:logical_name] = "app#{app[:name].tr('^A-Za-z0-9', '')}#{@@resource_id}"
          @@resource_id = @@resource_id + 1
          apps << app
        end
      end
      all_resources.merge!({:opsworks_apps => apps})
    rescue => e
      if region.eql?("us-gov-west-1")
        all_errors.merge!({:opsworks_apps => "Not supported in this region"})
      else
        all_errors.merge!({:opsworks_apps => e.message})
      end
      all_resources.merge!({:opsworks_apps => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:logical_name]
  end
  
  def self.get_resource_attributes(resource)
    return "Application Name: #{resource[:name]} \n" +
           "Short Name: #{resource[:shortname]} \n" +
           "Description: #{resource[:description]}\n" +
           "Stack Name: #{resource[:stack_name]}"
  end

  def self.OutputList(resource)
    return {"Application Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = OPSWORKS_Apps.ResourceName(resource)
    super(@name, "AWS::OpsWorks::App")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    #props.merge!({"ApplicationName" => resource[:application_name]}) if resource[:application_name]
    props.merge!({"Description" => resource[:description]}) if resource[:description]
    props.merge!({"Domains" => resource[:domains]}) if resource[:domains]
    props.merge!({"EnableSsl" => resource[:enable_ssl].to_s}) if resource[:enable_ssl]
    props.merge!({"Name" => resource[:name]}) if resource[:name]
    props.merge!({"Shortname" => resource[:shortname]}) if resource[:shortname]
    props.merge!({"Type" => resource[:type]}) if resource[:type]

    props.merge!({"StackId" => ref_or_literal(:opsworks_stacks, resource[:stack_name], template, name_mappings)}) if resource[:stack_name]

    source = {}
    if resource[:app_source]
      source["Password"] = resource[:app_source][:password] if resource[:app_source][:password]
      source["Revision"] = resource[:app_source][:revision] if resource[:app_source][:revision]
      source["SshKey"] = resource[:app_source][:ssh_key] if resource[:app_source][:ssh_key]
      source["Type"] = resource[:app_source][:type] if resource[:app_source][:type]
      source["Url"] = resource[:app_source][:url] if resource[:app_source][:url]
      source["Username"] = resource[:app_source][:username] if resource[:app_source][:username]
    end
    props.merge!({"AppSource" => source}) if !source.empty?

    attrs = {}
    resource[:attributes].each do |key,value|
      if value
        attrs[key] = value
      end
    end if resource[:attributes]
    props.merge!({"Attributes" => attrs}) if !attrs.empty?

    ssl = {}
    if resource[:ssl_configuration]
      ssl["Certificate"] = resource[:ssl_configuration][:certificate] if resource[:ssl_configuration][:certificate]
      ssl["Chain"] = resource[:ssl_configuration][:chain] if resource[:ssl_configuration][:chain]
      ssl["PrivateKey"] = resource[:ssl_configuration][:private_key] if resource[:ssl_configuration][:private_key]
    end
    props.merge!({"SslConfiguration" => ssl}) if !ssl.empty?

    return @cf_definition.deep_merge({ OPSWORKS_Apps.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
