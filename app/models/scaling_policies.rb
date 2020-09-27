class Scaling_policies < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Auto Scaling policies we care about
      as = Aws::AutoScaling::Client.new({ :region => region })
      all_resources.merge!({:scaling_policies => as.describe_policies().to_h[:scaling_policies]})
    rescue => e
      all_errors.merge!({:scaling_policies => e.message})
      all_resources.merge!({:scaling_policies => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "scaling" + resource[:policy_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    return {}
  end
  
  def self.get_resource_attributes(resource)
    return "PolicyName: #{resource[:policy_name]} \n" +
           "AdjustmentType: #{resource[:adjustment_type]} \n" +
           "ScalingAdjustment: #{resource[:scaling_adjustment]}"
  end

  def self.OutputList(resource)
    return {"Scaling Policy Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Scaling_policies.ResourceName(resource)
    super(@name, "AWS::AutoScaling::ScalingPolicy")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"AdjustmentType" => resource[:adjustment_type]}) if resource[:adjustment_type]
    props.merge!({"Cooldown" => resource[:cooldown].to_s}) if resource[:cooldown]
    props.merge!({"PolicyType" => resource[:policy_type].to_s}) if resource[:policy_type]
    props.merge!({"MinAdjustmentStep" => resource[:min_adjustment_step].to_s}) if resource[:min_adjustment_step] 
    if resource[:scaling_adjustment]
      props.merge!({"ScalingAdjustment" => resource[:scaling_adjustment]})
    else
      step_adjustments = []
      resource[:step_adjustments].each do |step_adjustment|
        s_a = {}
        s_a.merge!({"ScalingAdjustment" => step_adjustment[:scaling_adjustment]}) if step_adjustment[:scaling_adjustment]
        s_a.merge!({"MetricIntervalLowerBound" => step_adjustment[:metric_interval_lower_bound]}) if step_adjustment[:metric_interval_lower_bound]
        s_a.merge!({"MetricIntervalUpperBound" => step_adjustment[:metric_interval_upper_bound]}) if step_adjustment[:metric_interval_upper_bound]
        step_adjustments.push(s_a)
      end
      props.merge!({"StepAdjustments" => step_adjustments})
    end
    props.merge!({"AutoScalingGroupName" => ref_or_literal(:as_groups, resource[:auto_scaling_group_name], template, name_mappings)}) if resource[:auto_scaling_group_name]

    return @cf_definition.deep_merge({ Scaling_policies.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
