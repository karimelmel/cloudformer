class EB_Templates < CF_converter
  
  attr_accessor :name
  @@resource_index = 0
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the EB Applications
      eb = AWS::ElasticBeanstalk.new(:region => region)
      templates = []
      if all_resources[:eb_applications]
        all_resources[:eb_applications].each do |app|
          if app[:configuration_templates]
            app[:configuration_templates].each do |template_name|
              eb.client.describe_configuration_settings({:application_name => app[:application_name], :template_name => template_name}).data[:configuration_settings].each do |template|
                options = eb.client.describe_configuration_options({:application_name => app[:application_name], :template_name => template_name})[:options]
                option_settings = []
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
                full_template = template.clone
                full_template.reject!{ |k| k == :date_created }
                full_template.reject!{ |k| k == :date_updated }
                full_template.reject!{ |k| k == :option_settings }
                full_template[:option_settings] = option_settings if !option_settings.empty?
                full_template[:name] = "template#{template[:template_name].tr('^A-Za-z0-9', '')}#{@@resource_index}"
                @@resource_index = @@resource_index + 1
                templates << full_template
              end
            end
          end
        end
      end
      all_resources.merge!({:eb_templates => templates})
    rescue => e
      if region.eql?("us-gov-west-1") || region.eql?("cn-north-1") || region.eql?("cn-northwest-1")
        all_errors.merge!({:eb_templates => "Not supported in this region"})
      else
        all_errors.merge!({:templates => e.message})
      end
      all_resources.merge!({:eb_templates => {}})
    end
  end
  
  def self.ResourceName(resource)
    return resource[:name]
  end
  
  def self.get_resource_attributes(resource)
    return "Application Name: #{resource[:application_name]} \n" +
           "Description: #{resource[:description]}" +
           "Template Name: #{resource[:template_name]}"
  end

  def self.OutputList(resource)
    return {"Template Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = EB_Templates.ResourceName(resource)
    super(@name, "AWS::ElasticBeanstalk::ConfigurationTemplate")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"ApplicationName" => ref_or_literal(:eb_applications, resource[:application_name], template, name_mappings)}) if resource[:application_name]
    props.merge!({"Description" => resource[:description]}) if resource[:description]
    props.merge!({"SolutionStackName" => resource[:solution_stack_name]}) if resource[:solution_stack_name]

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

    return @cf_definition.deep_merge({ EB_Templates.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
