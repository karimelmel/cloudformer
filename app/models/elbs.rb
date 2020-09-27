class Elbs < CF_converter
  
  attr_accessor :name

  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Load Balancers we care about
      elb = AWS::ELB.new(:region => region)
      lbs = []
      elb.client.describe_load_balancers().data[:load_balancer_descriptions].each do |lb|
        full_lb = lb.clone
        full_lb.reject!{ |k| k == :created_time }
        attr = elb.client.describe_load_balancer_attributes({:load_balancer_name => lb[:load_balancer_name]}).data[:load_balancer_attributes]
        full_lb[:access_log] = attr[:access_log] if attr[:access_log]
        full_lb[:cross_zone_load_balancing] = attr[:cross_zone_load_balancing] if attr[:cross_zone_load_balancing]
        full_lb[:connection_draining] = attr[:connection_draining] if attr[:connection_draining]
        full_lb[:connection_settings] = attr[:connection_settings] if attr[:connection_settings]
        elb.client.describe_tags({:load_balancer_names => [lb[:load_balancer_name]]}).data[:tag_descriptions].each do |tags|
          full_lb[:tags] = tags[:tags]
        end
        if full_lb[:policies] && full_lb[:policies][:other_policies] && !full_lb[:policies][:other_policies].empty?
          policies = elb.client.describe_load_balancer_policies({:load_balancer_name => lb[:load_balancer_name], :policy_names => full_lb[:policies][:other_policies]})[:policy_descriptions]
          full_lb[:full_policies] = JSON.generate(policies)
        end
        lbs << full_lb
      end
      all_resources.merge!({:elbs => lbs})
    rescue => e
      all_errors.merge!({:elbs => e.message})
      all_resources.merge!({:elbs => {}})
    end
  end

  def self.ResourceName(resource)
    return "elb" + resource[:load_balancer_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    retInstances = []
    if all_resources[:instances]
      all_resources[:instances].each do |instance|
        resource[:instances].each do |lb_instance|
          retInstances.push(instance) if lb_instance[:instance_id] == instance[:instance_id]
        end if resource[:instances]
      end      
    end

    retASGs = []
    if all_resources[:as_groups]
      all_resources[:as_groups].each do |asg|
        retASGs.push(asg) if asg[:load_balancer_names].include?(resource[:load_balancer_name])
      end      
    end

    sgResources = []
    if all_resources[:security_groups]
      all_resources[:security_groups].each do |sg|
        sgResources.push(sg) if resource[:security_groups].include?(sg[:group_id])
      end      
    end

    return { :instances => retInstances, :as_groups => retASGs, :security_groups => sgResources }
  end

  def self.get_resource_attributes(resource)
    tags = ""
    if resource[:tags]
      resource[:tags].each do |key, value|
        tags = tags + "\n" "#{key}: #{value} "
      end
    end          

    return "DNS Name: #{resource[:dns_name]} \n" +
           "Availability Zones: #{resource[:availability_zones]} " + tags
  end
  
  def self.OutputList(resource)
    return {"Load Balancer Name" => "Name,Ref",
            "DNS Name" => "DNS,GetAtt,DNSName",
            "Canonical Hosted Zone Name" => "CanonicalHostedZoneName,GetAtt,CanonicalHostedZoneName",
            "Canonical Hosted Zone Name ID" => "CanonicalHostedZoneNameID,GetAtt,CanonicalHostedZoneNameID",
            "Source Security Group Name" => "SourceSecurityGroupName,GetAtt,SourceSecurityGroup.GroupName",
            "Source Security Group Owner" => "SourceSecurityGroupOwnerAlias,GetAtt,SourceSecurityGroup.OwnerAlias",
            "Endpoint URL" => "URL,Join,,http://,GetAtt,DNSName"
           }
  end

  def initialize(resource)
    @name = Elbs.ResourceName(resource)
    super(@name, "AWS::ElasticLoadBalancing::LoadBalancer")
  end
  
  def convert(resource, template, name_mappings)
    in_vpc = resource[:subnets] && resource[:subnets].any?
    props = {}
    props.merge!({"AvailabilityZones" => resource[:availability_zones]}) if resource[:availability_zones] && !resource[:availability_zones].empty? && !in_vpc
    props.merge!({"Scheme" => resource[:scheme]}) if resource[:scheme] && resource[:scheme] == "internal"

    all_policies = []
    if resource[:full_policies] && !resource[:full_policies].empty?
      JSON.parse(resource[:full_policies]).each do |policy|
        # Fill in policies removing any reserved ones
        if policy["policy_name"] &&
           !policy["policy_name"].match(/^ELBSample-/) &&
           !policy["policy_name"].match(/^ELBSecurityPolicy-/)
          new_policy = {}
          new_policy["PolicyName"] = policy["policy_name"] if policy["policy_name"]
          new_policy["PolicyType"] = policy["policy_type_name"] if policy["policy_type_name"]
          attrs = []
          policy["policy_attribute_descriptions"].each do |attr|
            new_attr = {}
            new_attr["Name"] = attr["attribute_name"] if attr["attribute_name"]
            new_attr["Value"] = attr["attribute_value"].to_s if attr["attribute_value"]
            attrs << new_attr if !new_attr.empty?
          end if policy["policy_attribute_descriptions"]
          new_policy["Attributes"] = attrs if !attrs.empty?
          ports = []
          resource[:backend_server_descriptions].each do |instance_policy|
            if instance_policy[:policy_names] &&
               instance_policy[:policy_names].include?(policy["policy_name"]) && 
               instance_policy[:instance_port]
              ports << instance_policy[:instance_port].to_s
            end
          end if resource[:backend_server_descriptions]
          new_policy["InstancePorts"] = ports if !ports.empty?
          all_policies << new_policy if !new_policy.empty?
        end
      end
    end
    props.merge!({"Policies" => all_policies}) if !all_policies.empty?

    if resource[:subnets]
      subnets = []
      resource[:subnets].each do |subnet|
        subnets.push(ref_or_literal(:subnets, subnet, template, name_mappings))
      end
      props.merge!({"Subnets" => subnets}) if !subnets.empty?
    end

    if resource[:health_check] && !resource[:health_check].empty? 
      props.merge!({"HealthCheck" => {
        "HealthyThreshold"   => resource[:health_check][:healthy_threshold].to_s,
        "Interval"           => resource[:health_check][:interval].to_s,
        "Target"             => resource[:health_check][:target].to_s,
        "Timeout"            => resource[:health_check][:timeout].to_s,
        "UnhealthyThreshold" => resource[:health_check][:unhealthy_threshold].to_s
      }})
    end

    if resource[:access_log]
      logs = {}
      logs["EmitInterval"] = resource[:access_log][:emit_interval].to_s if resource[:access_log][:emit_interval]
      logs["Enabled"] = resource[:access_log][:enabled].to_s if resource[:access_log][:enabled]
      logs["S3BucketName"] = resource[:access_log][:s3_bucket_name] if resource[:access_log][:s3_bucket_name]
      logs["S3BucketPrefix"] = resource[:access_log][:s3_bucket_prefix] if resource[:access_log][:s3_bucket_prefix]
      props.merge!({"AccessLoggingPolicy" => logs}) if !logs.empty?
    end

    if resource[:connection_draining]
      draining = {}
      draining["Enabled"] = resource[:connection_draining][:enabled].to_s
      draining["Timeout"] = resource[:connection_draining][:timeout].to_s if resource[:connection_draining][:timeout]
      props.merge!({"ConnectionDrainingPolicy" => draining}) if !draining.empty?
    end
    
    if resource[:connection_settings]
      settings = {}
      settings["IdleTimeout"] = resource[:connection_settings][:idle_timeout].to_s if resource[:connection_settings][:idle_timeout]
      props.merge!({"ConnectionSettings" => settings}) if !settings.empty?
    end

    if resource[:cross_zone_load_balancing]
      props.merge!({"CrossZone" => resource[:cross_zone_load_balancing][:enabled].to_s}) if resource[:cross_zone_load_balancing][:enabled]
    end

    if resource[:instances]
      instances = []
      resource[:instances].each do |instance|
        exists = false
        template.all_resources[:instances].each do |all|
          exists = exists || (all[:instance_id] == instance[:instance_id])
        end
        instances.push(ref_or_literal(:instances, instance[:instance_id], template, name_mappings)) if exists    
      end
      props.merge!({"Instances" => instances}) if !instances.empty?      
    end
    
    if resource[:security_groups]
      groups = []
      resource[:security_groups].each do |group|
        groups.push(ref_or_literal(:security_groups, group, template, name_mappings))        
      end
      props.merge!({"SecurityGroups" => groups}) if !groups.empty?
    end

    if resource[:listener_descriptions]
      listeners = []
      resource[:listener_descriptions].each do |listener|
        lprops = {};
        lprops.merge!({"InstancePort"     => listener[:listener][:instance_port].to_s})
        lprops.merge!({"LoadBalancerPort" => listener[:listener][:load_balancer_port].to_s})
        lprops.merge!({"Protocol"         => listener[:listener][:protocol]})
        lprops.merge!({"InstanceProtocol" => listener[:listener][:instance_protocol]})
        lprops.merge!({"SSLCertificateId" => listener[:listener][:ssl_certificate_id].to_s}) if listener[:listener][:ssl_certificate_id]
        lprops.merge!({"PolicyNames"      => listener[:policy_names]}) if listener[:policy_names] && !listener[:policy_names].empty?
        listeners.push(lprops)
      end
      props.merge!({"Listeners" => listeners}) if !listeners.empty?
    end

    if resource[:policies]
      if resource[:policies][:app_cookie_stickiness_policies]
        policies = []
        resource[:policies][:app_cookie_stickiness_policies].each do |policy|
          policies.push({
            "PolicyName" => policy[:policy_name].to_s,
            "CookieName" => policy[:cookie_name].to_s
          })
        end
        props.merge!({"AppCookieStickinessPolicy" => policies}) if !policies.empty?
      end

      if resource[:policies][:lb_cookie_stickiness_policies]
        policies = []
        resource[:policies][:lb_cookie_stickiness_policies].each do |policy|
          policies.push({
            "PolicyName"             => policy[:policy_name].to_s,
            "CookieExpirationPeriod" => policy[:cookie_expiration_period].to_s
          })
        end
        props.merge!({"LBCookieStickinessPolicy" => policies}) if !policies.empty?
      end

      if resource[:policies][:other_policies]
        policies = []
        props.merge!({"Policies" => policies}) if !policies.empty?
      end
    end

    tags = []
    if resource[:tags]
      resource[:tags].each do |tag|
        tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
      end
    end          
    props.merge!({"Tags" => tags}) if !tags.empty?      

    return @cf_definition.deep_merge({ Elbs.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
