class Alarms < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the CloudWatchAlarms we care about
      cw = AWS::CloudWatch.new(:region => region)
      all_alarms = cw.client.describe_alarms().data[:metric_alarms]
      alarms = []
      all_alarms.each do |alarm|
        fixed_alarm = alarm.clone
        fixed_alarm.reject!{ |k| k == :alarm_configuration_updated_timestamp }
        fixed_alarm.reject!{ |k| k == :state_updated_timestamp }
        alarms << fixed_alarm
      end
      all_resources.merge!({:alarms => alarms})
    rescue => e
      all_errors.merge!({:alarms => e.message})
      all_resources.merge!({:alarms => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "alarm" + resource[:alarm_name].tr('^A-Za-z0-9', '')
  end

  def self.get_resource_attributes(resource)
    return "Namespace: #{resource[:namespace]} \n" +
           "Metric Name: #{resource[:metric_name]} \n" +
           "Statistic: #{resource[:statistic]} \n" +
           "Dimensions: #{resource[:dimensions]}"
           
  end  

  def self.OutputList(resource)
    return {"Alarm Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Alarms.ResourceName(resource)
    super(@name, "AWS::CloudWatch::Alarm")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"ActionsEnabled" => resource[:actions_enabled].to_s}) if resource[:actions_enabled]
    props.merge!({"AlarmDescription" => resource[:alarm_description]}) if resource[:alarm_description]
    props.merge!({"ComparisonOperator" => resource[:comparison_operator]}) if resource[:comparison_operator]
    props.merge!({"EvaluationPeriods" => resource[:evaluation_periods].to_s}) if resource[:evaluation_periods]
    props.merge!({"MetricName" => resource[:metric_name]}) if resource[:metric_name]
    props.merge!({"Namespace" => resource[:namespace]}) if resource[:namespace]
    props.merge!({"Period" => resource[:period].to_s}) if resource[:period]
    props.merge!({"Statistic" => resource[:statistic]}) if resource[:statistic]
    props.merge!({"Threshold" => resource[:threshold].to_s}) if resource[:threshold]
    props.merge!({"Unit" => resource[:unit]}) if resource[:unit]
    
    if resource[:ok_actions]
      actions = []
      resource[:ok_actions].each do |action|
        actions << ref_or_literal(:scaling_policies, action, template, name_mappings)
      end
      props.merge!({"OKActions" => actions}) if !actions.empty?
    end

    if resource[:alarm_actions]
      actions = []
      resource[:alarm_actions].each do |action|
        actions << ref_or_literal(:scaling_policies, action, template, name_mappings)
      end
      props.merge!({"AlarmActions" => actions}) if !actions.empty?
    end

    if resource[:insufficient_data_actions]
      actions = []
      resource[:insufficient_data_actions].each do |action|
        actions << ref_or_literal(:scaling_policies, action, template, name_mappings)
      end
      props.merge!({"InsufficientDataActions" => actions}) if !actions.empty?
    end

    if resource[:dimensions]
      dims = []
      resource[:dimensions].each do |dim|
        dims.push({"Name" => dim[:name], "Value" => dim[:value]})
      end
      props.merge!({"Dimensions" => dims}) if !dims.empty?      
    end
    
    return @cf_definition.deep_merge({ Alarms.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
