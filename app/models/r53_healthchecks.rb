class R53_Healthchecks < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Route53 health checks we care about
      r53 = AWS::Route53.new()
      all_resources.merge!({:r53_healthchecks => r53.client.list_health_checks().data[:health_checks]})
    rescue => e
      if region.eql?("us-gov-west-1")
        all_errors.merge!({:r53_healthchecks => "Not supported in this region"})
      else
        all_errors.merge!({:r53_healthchecks => e.message})
      end
      all_resources.merge!({:r53_healthchecks => {}})
    end
  end

  def self.ResourceName(resource)
    return resource[:id].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "IP Address: #{resource[:health_check_config][:ip_address]}\n" +
           "Domain: #{resource[:health_check_config][:fully_qualified_domain_name]}\n" +
           "Port: #{resource[:health_check_config][:port]}\n" +
           "Path: #{resource[:health_check_config][:resource_path]}\n" +
           "Type: #{resource[:health_check_config][:type]}\n"
  end  
  
  def self.OutputList(resource)
    return {"Health Check" => "Name,Ref"}
  end

  def initialize(resource)
    @name = R53_Healthchecks.ResourceName(resource)
    super(@name, "AWS::Route53::HealthCheck")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    config = {}
    config["FailureThreshold"] = resource[:health_check_config][:failure_threshold].to_s if resource[:health_check_config][:failure_threshold]
    config["FullyQualifiedDomainName"] = resource[:health_check_config][:fully_qualified_domain_name].to_s if resource[:health_check_config][:fully_qualified_domain_name]
    config["IPAddress"] = resource[:health_check_config][:ip_address].to_s if resource[:health_check_config][:ip_address]
    config["Port"] = resource[:health_check_config][:port].to_s if resource[:health_check_config][:port]
    config["RequestInterval"] = resource[:health_check_config][:request_interval].to_s if resource[:health_check_config][:request_interval]
    config["ResourcePath"] = resource[:health_check_config][:resource_path].to_s if resource[:health_check_config][:resource_path]
    config["SearchString"] = resource[:health_check_config][:search_string].to_s if resource[:health_check_config][:search_string]
    config["Type"] = resource[:health_check_config][:type].to_s if resource[:health_check_config][:type]

    props.merge!({"HealthCheckConfig" => config}) if ! config.empty?

    return @cf_definition.deep_merge({ R53_Healthchecks.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
