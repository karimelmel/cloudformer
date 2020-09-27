class AS_Groups < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Auto Scaling Groups we care about
      as = Aws::AutoScaling::Client.new(:region => region)
      asgs = []
      as.describe_auto_scaling_groups().auto_scaling_groups.each do |asg|
        full_asg = asg.clone.to_h
        notifications = as.describe_notification_configurations(:auto_scaling_group_names => [asg.auto_scaling_group_name]).to_h
        full_asg.merge!(:notification_configurations => notifications[:notification_configurations])
        full_asg.reject!{ |k| k == :created_time }
        asgs << full_asg
      end
      all_resources.merge!({:as_groups => asgs})
    rescue => e
      all_errors.merge!({:as_groups => e.message})
      all_resources.merge!({:as_groups => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "asg" + resource[:auto_scaling_group_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    triggerResources = []
    lcResources = []
    policyResources = []
    actionResources = []
    if all_resources[:triggers]
      all_resources[:triggers].each do |trigger|
        triggerResources.push(trigger) if resource[:auto_scaling_group_name] == trigger[:auto_scaling_group_name]
      end      
    end
    if all_resources[:scaling_policies]
      all_resources[:scaling_policies].each do |policy|
        policyResources.push(policy) if resource[:auto_scaling_group_name] == policy[:auto_scaling_group_name]
      end      
    end
    if all_resources[:scheduled_actions]
      all_resources[:scheduled_actions].each do |action|
        actionResources.push(action) if resource[:auto_scaling_group_name] == action[:auto_scaling_group_name]
      end      
    end
    if all_resources[:launch_configs]
      all_resources[:launch_configs].each do |lc|
        lcResources.push(lc) if resource[:launch_configuration_name] == lc[:launch_configuration_name]
      end
    end
    return { :triggers => triggerResources, :launch_configs => lcResources, :scaling_policies => policyResources }
  end

  def self.get_resource_attributes(resource)
    tags = ""
    if resource[:tags]
      resource[:tags].each do |tag|
        tags = tags + "\n" "#{tag[:key]}: #{tag[:value]} (#{tag[:propagate_at_launch]}) "
      end
    end          
    return "Launch Config Name: #{resource[:launch_configuration_name]} \n" +
           "Availability Zones: #{resource[:availability_zones]} \n" +
           "Load Balancer Names: #{resource[:load_balancer_names]} \n" +
           "Minimum Size: #{resource[:min_size]}\n" +
           "Maximum Size: #{resource[:max_size]}\n" +
           "Desired Capacity: #{resource[:desired_capacity]} " + tags
  end

  def self.OutputList(resource)
    return {"Auto Scaling Group Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = AS_Groups.ResourceName(resource)
    super(@name, "AWS::AutoScaling::AutoScalingGroup")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"AvailabilityZones" => resource[:availability_zones]}) if resource[:availability_zones]
    props.merge!({"Cooldown" => resource[:default_cooldown].to_s}) if resource[:default_cooldown]
    props.merge!({"DesiredCapacity" => resource[:desired_capacity].to_s}) if resource[:desired_capacity]
    props.merge!({"HealthCheckGracePeriod" => resource[:health_check_grace_period].to_s}) if resource[:health_check_grace_period]
    props.merge!({"HealthCheckType" => resource[:health_check_type]}) if resource[:health_check_type]
    props.merge!({"MaxSize" => resource[:max_size].to_s}) if resource[:max_size]
    props.merge!({"MinSize" => resource[:min_size].to_s}) if resource[:min_size]
    props.merge!({"PlacementGroup" => resource[:placement_group].to_s}) if resource[:placement_group]
    props.merge!({"AssociatePublicIpAddress" => resource[:associate_public_ip_address] ? "true" : "false" }) if resource[:associate_public_ip_address]

    subnets = []
    resource[:vpc_zone_identifier].split(",").each do |subnet|
      subnets.push(ref_or_literal(:subnets, subnet, template, name_mappings))
    end if resource[:vpc_zone_identifier]
    props.merge!({"VPCZoneIdentifier" => subnets }) if !subnets.empty?

    topic_arn = ""
    notifications = []
    if resource[:notification_configurations]
      notification_configuration = {}
      resource[:notification_configurations].each do |notify|
        if !notification_configuration[:topic_arn] || notification_configuration[:topic_arn] != notify[:topic_arn]
          notification_configuration[:topic_arn] = notify[:topic_arn]
          notification_configuration[:notification_types] = []
        end
        notification_configuration[:notification_types] << notify[:notification_type]
      end
      notification = {}
      notification["TopicARN"] = notification_configuration[:topic_arn] if notification_configuration[:topic_arn];
      notification["NotificationTypes"] = notification_configuration[:notification_types] if notification_configuration[:notification_types]
      notifications.push(notification) if !notification.empty?
    end
    props.merge!({"NotificationConfigurations" => notifications}) if !notifications.empty?
    
    props.merge!({"LaunchConfigurationName" => ref_or_literal(:launch_configs, resource[:launch_configuration_name], template, name_mappings)}) if resource[:launch_configuration_name]
    
    if resource[:load_balancer_names]
      elbs = []
      resource[:load_balancer_names].each do |elb|
        elbs.push(ref_or_literal(:elbs, elb, template, name_mappings))        
      end
      props.merge!({"LoadBalancerNames" => elbs}) if !elbs.empty?      
    end

    tags = []
    if resource[:tags]
      resource[:tags].each do |tag|
        tags.push({"Key" => tag[:key], "Value" => tag[:value], "PropagateAtLaunch" => tag[:propagate_at_launch]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
      end
    end          
    props.merge!({"Tags" => tags}) if !tags.empty?      

    metrics = []
    if resource[:enabled_metrics]
      metric = {}
      resource[:enabled_metrics].each do |enabled_metric|
        if !metric[:granularity] || metric[:granularity] != enabled_metric[:granularity]
          metric[:granularity] = enabled_metric[:granularity]
          metric[:metric] = []
        end
        metric[:metric] << enabled_metric[:metric]
      end
      metrics_collection = {}
      metrics_collection["Granularity"] = metric[:granularity] if metric[:granularity];
      metrics_collection["Metrics"] = metric[:metric] if metric[:metric]
      metrics.push(metrics_collection) if !metrics_collection.empty?
    end
    props.merge!({"MetricsCollection" => metrics}) if !metrics.empty?
    termination_policies = []
    if resource[:termination_policies]
      resource[:termination_policies].each do |termination_policy|
        termination_policies.push(termination_policy)
      end
    end
    props.merge!({"TerminationPolicies" => termination_policies}) if !termination_policies.empty?
   
    return @cf_definition.deep_merge({ AS_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
