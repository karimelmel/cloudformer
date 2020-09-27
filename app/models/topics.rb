class Topics < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the SNS topics we care about
      sns = AWS::SNS.new(:region => region)
      topic_resources = []
      sns.topics.each do |topic|
        subscriptions = []
        topic.subscriptions.each do |subscription|
          subscriptions << {:endpoint => subscription.endpoint, :protocol => subscription.protocol}
        end
        topic_resources << {:name => topic.display_name, :subscriptions => subscriptions}
      end
      all_resources.merge!({:topics => topic_resources})
    rescue => e
      all_errors.merge!({:topics => e.message})
      all_resources.merge!({:topics => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "topic" + resource[:name].tr('^A-Za-z0-9', '') 
  end
  
  def self.get_dependencies(resource, all_resources)
    topic_policies = []
    if all_resources[:topic_policies]
      all_resources[:topic_policies].each do |policy|
        topic_policies.push(policy) if resource[:name] == policy[:name]
      end      
    end
    return { :topic_policies => topic_policies }
  end
  
  def self.OutputList(resource)
    return {"Topic ARN" => "Name,Ref",
            "Topic Name" => "TopicName,GetAtt,TopicName"}
  end
  
  def initialize(resource)
    @name = Topics.ResourceName(resource)
    super(@name, "AWS::SNS::Topic")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"DisplayName" => resource[:name]}) if resource[:name]
    subscriptions = []
    resource[:subscriptions].each do |subscription|
      subscriptions.push({"Endpoint" => subscription[:endpoint], "Protocol" => subscription[:protocol]})
    end
    props.merge!({"Subscription" => subscriptions}) if !subscriptions.empty?
    return @cf_definition.deep_merge({ Topics.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props}}) 
  end
    
end
