class Scheduled_actions < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Auto Scaling policies we care about
      as = AWS::AutoScaling.new(:region => region)
      actions = []
      as.client.describe_scheduled_actions().data[:scheduled_update_group_actions].each do |action|
        full_action = action.clone
        full_action.reject!{ |k| k == :time }
        full_action.reject!{ |k| k == :start_time }
        full_action.reject!{ |k| k == :end_time }
        start_time = action[:start_time].to_s()
        full_action[:start_time] = action[:start_time].to_s().gsub(/ UTC/, "Z").gsub(/ /, "T")
        full_action[:end_time] = action[:end_time].to_s().gsub(/ UTC/, "Z").gsub(/ /, "T")
        actions << full_action
      end
      all_resources.merge!({:scheduled_actions => actions})
    rescue => e
      all_errors.merge!({:scheduled_actions => e.message})
      all_resources.merge!({:scheduled_actions => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "scheduled" + resource[:scheduled_action_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    return {}
  end
  
  def self.get_resource_attributes(resource)
    return "GroupName: #{resource[:auto_scaling_group_name]} \n" +
           "ScheduledActionName: #{resource[:scheduled_action_name]}"
  end

  def self.OutputList(resource)
    return {"Scheduled Action Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Scheduled_actions.ResourceName(resource)
    super(@name, "AWS::AutoScaling::ScheduledAction")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"DesiredCapacity" => resource[:adjustment_type]}) if resource[:adjustment_type]
    props.merge!({"EndTime" => resource[:end_time].to_s}) if resource[:end_time] && !resource[:end_time].empty?
    props.merge!({"MaxSize" => resource[:max_size].to_s}) if resource[:max_size]
    props.merge!({"MinSize" => resource[:min_size].to_s}) if resource[:min_size]
    props.merge!({"Recurrence" => resource[:recurrence].to_s}) if resource[:recurrence]
    props.merge!({"StartTime" => resource[:start_time].to_s}) if resource[:start_time] && !resource[:start_time].empty?

    props.merge!({"AutoScalingGroupName" => ref_or_literal(:as_groups, resource[:auto_scaling_group_name], template, name_mappings)}) if resource[:auto_scaling_group_name]

    return @cf_definition.deep_merge({ Scaling_policies.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
