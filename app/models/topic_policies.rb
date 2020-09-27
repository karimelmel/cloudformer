class Topic_Policies < CF_converter
  
  attr_accessor :name

  @@policy_id = 1
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)

    begin
      # Get all the SNS topics we care about
      sns = AWS::SNS.new(:region => region)
      topic_policies = []
      sns.topics.each do |topic|
        attr = sns.client.get_topic_attributes({:topic_arn => topic.arn})[:attributes]
        topic_policies << {:name => topic.display_name, :display_name => "Topic policy for #{topic.display_name}", :arn => attr["TopicArn"], :region => region, :owner_id => attr["Owner"], :policy => attr["Policy"]} if attr["Policy"]
      end
      all_resources.merge!({:topic_policies => topic_policies})
    rescue => e
      all_errors.merge!({:topic_policies => e.message})
      all_resources.merge!({:topic_policies => {}})
    end
  end

  def self.ResourceName(resource)
    return "snspolicy" + resource[:name].tr('^A-Za-z0-9', '') 
  end

  def initialize(resource)
    @name = Topic_Policies.ResourceName(resource)
    super(@name, "AWS::SNS::TopicPolicy")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    topic_name = ref_or_literal(:topics, resource[:name], template, name_mappings)
    props.merge!({"Topics" => [topic_name]})
    document = JSON.load(resource[:policy])
    document["Statement"].each do |statement|
       statement["Resource"] = ref_or_literal(:topics, resource[:name], template, name_mappings)
    end if document["Statement"]
    props.merge!({"PolicyDocument" => document}) if resource[:policy]
    return @cf_definition.deep_merge({ Topic_Policies.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
