class EB_Environments < CF_converter
  
  attr_accessor :name
  @@resource_index = 0
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the EB Versions
      eb = AWS::ElasticBeanstalk.new(:region => region)
      environments = []
      eb.client.describe_environments({:include_deleted => false}).data[:environments].each do |environment|
        option_settings = []
        eb.client.describe_configuration_settings({:application_name => environment[:application_name], :environment_name => environment[:environment_name]}).data[:configuration_settings].each do |template|
          options = eb.client.describe_configuration_options({:application_name => environment[:application_name], :environment_name => environment[:environment_name]})[:options]
          template[:option_settings].each do |setting|
            options.each do |option|
              if setting[:namespace].eql?(option[:namespace]) &&
                 !["aws:elasticbeanstalk:control", "aws:cloudformation:template:parameter"].include?(setting[:namespace]) && 
                 setting[:option_name].eql?(option[:name]) &&
                 setting[:value] &&
                 !(option[:default_value] && option[:default_value].eql?(setting[:value]))
                # Remove any internal refs
                setting_value = ((setting[:value].sub /{\"Ref\".*\"}/, '').sub /,$/, '').sub /^,/, ''
                if !setting_value.empty?
                  new_setting = {:namespace => setting[:namespace], :option_name => setting[:option_name], :value => setting_value}
                  option_settings << new_setting
                end
              end
            end if !options.empty?
          end if template[:option_settings]
        end
        full_environment = environment.clone
        full_environment.reject!{ |k| k == :date_created }
        full_environment.reject!{ |k| k == :date_updated }
        full_environment[:option_settings] = option_settings if !option_settings.empty?
        full_environment[:name] = "env#{environment[:environment_name].tr('^A-Za-z0-9', '')}#{@@resource_index}"
        @@resource_index = @@resource_index + 1
        environments << full_environment
      end
      all_resources.merge!({:eb_environments => environments})
    rescue => e
      if region.eql?("us-gov-west-1") || region.eql?("cn-north-1") || region.eql?("cn-northwest-1")
        all_errors.merge!({:eb_environments => "Not supported in this region"})
      else
        all_errors.merge!({:eb_environments => e.message})
      end
      all_resources.merge!({:eb_environments => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:name]
  end

  def self.post_load(template, region)
    # Remove all environment created resources
    template.all_resources[:eb_environments].each do |env|
      eb = AWS::ElasticBeanstalk.new(:region => region)
      eb_resources = eb.client.describe_environment_resources({:environment_id => env[:environment_id]}).data[:environment_resources]

      eb_resources[:auto_scaling_groups].each do |eb_asg|
        as_groups = []
        template.all_resources[:as_groups].each do |all_asg|
          as_groups << all_asg if !all_asg[:auto_scaling_group_name].eql?(eb_asg[:name])
          scaling_policies = []
          template.all_resources[:scaling_policies].each do |all_sp|
            scaling_policies << all_sp if !all_sp[:auto_scaling_group_name].eql?(eb_asg[:name])
          end if template.all_resources[:scaling_policies]
          template.all_resources[:scaling_policies] = scaling_policies
        end if template.all_resources[:as_groups]
        template.all_resources[:as_groups] = as_groups
      end if eb_resources[:auto_scaling_groups]

      eb_resources[:launch_configurations].each do |eb_lc|
        launch_configs = []
        template.all_resources[:launch_configs].each do |all_lc|
          launch_configs << all_lc if !all_lc[:launch_configuration_name].eql?(eb_lc[:name])
        end if template.all_resources[:launch_configs]
        template.all_resources[:launch_configs] = launch_configs
      end if eb_resources[:launch_configurations]

      eb_resources[:load_balancers].each do |eb_elb|
        elbs = []
        template.all_resources[:elbs].each do |all_elb|
          elbs << all_elb if !all_elb[:load_balancer_name].eql?(eb_elb[:name])
        end if template.all_resources[:elbs]
        template.all_resources[:elbs] = elbs
      end if eb_resources[:load_balancers]

      eb_resources[:queues].each do |eb_queue|
        queues = []
        template.all_resources[:queues].each do |all_queue|
          queues << all_queue if !all_queue[:name].eql?(eb_queue[:name])
        end if template.all_resources[:queues]
        template.all_resources[:queues] = queues
      end if eb_resources[:queues]

      alarms = []
      template.all_resources[:alarms].each do |all_alarm|
        alarms << all_alarm if !all_alarm[:alarm_name].match(/^awseb-e-/)
      end if template.all_resources[:alarms]
      template.all_resources[:alarms] = alarms

      sgs = []
      template.all_resources[:security_groups].each do |all_sg|
        sgs << all_sg if !all_sg[:group_name].match(/^awseb-e-/)
      end if template.all_resources[:security_groups]
      template.all_resources[:security_groups] = sgs

    end if template.all_resources && template.all_resources[:eb_environments]
  end
  
  def self.get_resource_attributes(resource)
    return "Application Name: #{resource[:application_name]} \n" +
           "Description: #{resource[:description]}" +
           "Version Label: #{resource[:version_label]}"
           "Environment Name: #{resource[:environment_name]}"
  end

  def self.OutputList(resource)
    return {"Environment Name" => "Name,Ref",
            "Endpoint URL" => "EndpointURL,GetAtt,EndpointURL"}
  end

  def initialize(resource)
    @name = EB_Environments.ResourceName(resource)
    super(@name, "AWS::ElasticBeanstalk::Environment")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"ApplicationName" => ref_or_literal(:eb_applications, resource[:application_name], template, name_mappings)}) if resource[:application_name]
    props.merge!({"Description" => resource[:description]}) if resource[:description]
    props.merge!({"SolutionStackName" => resource[:solution_stack_name]}) if resource[:solution_stack_name]
    props.merge!({"TemplateName" => ref_or_literal(:eb_templates, resource[:template_name], template, name_mappings)}) if resource[:template_name]
    props.merge!({"VersionLabel" => ref_or_literal(:eb_versions, resource[:version_label], template, name_mappings)}) if resource[:version_label]

    tier = {}
    if resource[:tier]
      tier["Name"] = resource[:tier][:name] if resource[:tier][:name] 
      tier["Type"] = resource[:tier][:type] if resource[:tier][:type] 
      tier["Version"] = resource[:tier][:version] if resource[:tier][:version] 
    end
    props.merge!({"Tier" => tier}) if !tier.empty?

    option_settings = []
    if resource[:option_settings]
      resource[:option_settings].each do |setting|
        option = {}
        option["Namespace"] = setting[:namespace] if setting[:namespace]
        option["OptionName"] = setting[:option_name] if setting[:option_name]
        option["Value"] = setting[:value] if setting[:value]
        option_settings << option if !option.empty?
      end 
    end
    props.merge!({"OptionSettings" => option_settings}) if !option_settings.empty?

    return @cf_definition.deep_merge({ EB_Environments.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
