class OPSWORKS_Stacks < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Opsworks Stacks
      opsworks = AWS::OpsWorks.new()
      stacks = opsworks.client.describe_stacks().data[:stacks]
      all_resources.merge!({:opsworks_stacks => stacks})
    rescue => e
      if region.eql?("us-gov-west-1")
        all_errors.merge!({:opsworks_stacks => "Not supported in this region"})
      else
        all_errors.merge!({:opsworks_stacks => e.message})
      end
      all_resources.merge!({:opsworks_stacks => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    layers = []
    if all_resources[:opsworks_layers]
      all_resources[:opsworks_layers].each do |layer|
        layers.push(layer) if resource[:stack_id].eql?(layer[:stack_id])
      end      
    end
    elbs = []
    if all_resources[:opsworks_elbs]
      all_resources[:opsworks_elbs].each do |elb|
        elbs.push(elb) if resource[:stack_id].eql?(elb[:stack_id])
      end      
    end
    apps = []
    if all_resources[:opsworks_apps]
      all_resources[:opsworks_apps].each do |app|
        apps.push(app) if resource[:stack_id].eql?(app[:stack_id])
      end      
    end
    return { :opsworks_layers => layers, :opsworks_elbs => elbs, :opsworks_apps => apps }
  end

  def self.get_resource_attributes(resource)
    return "Stack Name: #{resource[:name]}"
  end

  def self.OutputList(resource)
    return {"Stack Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = OPSWORKS_Stacks.ResourceName(resource)
    super(@name, "AWS::OpsWorks::Stack")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"CustomJson" => JSON.parse(resource[:custom_json])}) if resource[:custom_json]
    props.merge!({"DefaultAvailabilityZone" => resource[:default_availability_zone]}) if resource[:default_availability_zone]
    props.merge!({"DefaultInstanceProfileArn" => resource[:default_instance_profile_arn]}) if resource[:default_instance_profile_arn]
    props.merge!({"DefaultOs" => resource[:default_os]}) if resource[:default_os]
    props.merge!({"DefaultRootDevice" => resource[:default_root_device]}) if resource[:default_root_device]
    props.merge!({"DefaultSubnetId" => ref_or_literal(:subnets, resource[:default_subnet_id], template, name_mappings)}) if resource[:default_subnet_id]
    props.merge!({"Name" => resource[:name]}) if resource[:name]
    props.merge!({"HostnameTheme" => resource[:hostname_theme]}) if resource[:hostname_theme]
    props.merge!({"ServiceRoleArn" => resource[:service_role_arn]}) if resource[:service_role_arn]
    props.merge!({"UseCustomCookbooks" => resource[:use_custom_cookbooks].to_s}) if resource[:use_custom_cookbooks]
    props.merge!({"UseOpsworksSecurityGroups" => resource[:use_opsworks_security_groups].to_s}) if resource[:use_opsworks_security_groups]
    props.merge!({"VpcId" => ref_or_literal(:vpcs, resource[:vpc_id], template, name_mappings)}) if resource[:vpc_id]

    attrs = {}
    resource[:attributes].each do |key,value|
      if value
        attrs[key] = value
      end
    end if resource[:attributes]
    props.merge!({"Attributes" => attrs}) if !attrs.empty?

    if resource[:chef_configuration]
      chef = {}
      chef["BerkshelfVersion"] = resource[:chef_configuration][:berkshelf_version].to_s if resource[:chef_configuration][:berkshelf_version]
      chef["ManageBerkshelf"] = resource[:chef_configuration][:manage_berkshelf].to_s if resource[:chef_configuration][:manage_berkshelf]
      props.merge!({"ChefConfiguration" => chef}) if !chef.empty?
    end

    if resource[:configuration_manager]
      config = {}
      config["Name"] = resource[:configuration_manager][:name] if  resource[:configuration_manager][:name]
      config["Version"] = resource[:configuration_manager][:version] if  resource[:configuration_manager][:version]
      props.merge!({"ConfigurationManager" => config}) if !config.empty?
    end

    if resource[:custom_cookbook_source]
      cookbook = {}
      cookbook["Password"] = resource[:custom_cookbook_source][:password] if resource[:custom_cookbook_source][:password]
      cookbook["Revision"] = resource[:custom_cookbook_source][:revision] if resource[:custom_cookbook_source][:revision]
      cookbook["SshKey"] = resource[:custom_cookbook_source][:ssh_key] if resource[:custom_cookbook_source][:ssh_key]
      cookbook["Type"] = resource[:custom_cookbook_source][:type] if resource[:custom_cookbook_source][:type]
      cookbook["Url"] = resource[:custom_cookbook_source][:url] if resource[:custom_cookbook_source][:url]
      cookbook["Username"] = resource[:custom_cookbook_source][:username] if resource[:custom_cookbook_source][:username]
      props.merge!({"CustomCookbookSource" => cookbook}) if !cookbook.empty?
    end

    return @cf_definition.deep_merge({ OPSWORKS_Stacks.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
