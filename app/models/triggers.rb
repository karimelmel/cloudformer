class Triggers < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Auto Scaling Triggers we care about
      server = "autoscaling." + region + ".amazonaws.com"
      as = RightAws::AsInterface.new(aws_access_key_id, aws_secret_access_key, params={ :server => server })
      all_as_groups = as.describe_auto_scaling_groups()
      triggers = []
      all_as_groups.each do |as_group|
        triggers = triggers | as.describe_triggers(as_group[:auto_scaling_group_name])
      end
      all_resources.merge!({:triggers => triggers})
    rescue => e
      all_errors.merge!({:triggers => e.message})
      all_resources.merge!({:triggers => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "trigger" + resource[:trigger_name].tr('^A-Za-z0-9', '')
  end

  def self.get_resource_attributes(resource)
    return "Namespace: #{resource[:namespace]} \n" +
           "Metric Name: #{resource[:measure_name]} \n" +
           "Statistic: #{resource[:statistic]} \n" +
           "Auto Scaling Group: #{resource[:auto_scaling_group_name]}"  
  end  

  def self.OutputList(resource)
    return {"Trigger Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Triggers.ResourceName(resource)
    super(@name, "AWS::AutoScaling::Trigger")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"MetricName" => resource[:measure_name]}) if resource[:measure_name]
    props.merge!({"Namespace" => resource[:namespace]}) if resource[:namespace]
    props.merge!({"Period" => resource[:period].to_s}) if resource[:period]
    props.merge!({"Statistic" => resource[:statistic]}) if resource[:statistic]
    props.merge!({"Unit" => resource[:unit]}) if resource[:unit]
    props.merge!({"UpperBreachScaleIncrement" => resource[:upper_breach_scale_increment].to_s}) if resource[:upper_breach_scale_increment]
    props.merge!({"LowerBreachScaleIncrement" => resource[:lower_breach_scale_increment].to_s}) if resource[:lower_breach_scale_increment]
    props.merge!({"AutoScalingGroupName" => ref_or_literal(:as_groups, resource[:auto_scaling_group_name], template, name_mappings)}) if resource[:lower_breach_scale_increment]
    props.merge!({"BreachDuration" => resource[:breach_duration].to_s}) if resource[:breach_duration]
    props.merge!({"UpperThreshold" => resource[:upper_threshold].to_s}) if resource[:upper_threshold]
    props.merge!({"LowerThreshold" => resource[:lower_threshold].to_s}) if resource[:lower_threshold]
   
    if resource[:dimensions]
      dims = []
      resource[:dimensions].each do |dim, val|
        dims.push({"Name" => dim, "Value" => val})
      end
      props.merge!({"Dimensions" => dims}) if !dims.empty?      
    end
    
    return @cf_definition.deep_merge({ Triggers.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
