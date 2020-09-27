class Queues < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the SQS queues we care about
      sqs = AWS::SQS.new(:region => region)
      queue_resources = []
      sqs.queues.each do |queue|
        nameparts = queue.url.split("/")
        new_queue = { :name => nameparts.last, :queue_url => queue.url, :queue_arn => queue.arn, :visibility_timeout => queue.visibility_timeout, :delay_seconds => queue.delay_seconds, :maximum_message_size => queue.maximum_message_size, :message_retention_period => queue.message_retention_period, :receive_message_wait_timeout_seconds => queue.wait_time_seconds}
        attrs = sqs.client.get_queue_attributes({:queue_url => queue.url, :attribute_names => ["RedrivePolicy"]})[:attributes]
        redrive_policy = {}
        if attrs["RedrivePolicy"]
          redrive_policy = JSON.parse(attrs["RedrivePolicy"])
        end
        new_queue[:redrive_policy] = redrive_policy if !redrive_policy.empty?
        queue_resources << new_queue
      end
      all_resources.merge!({:queues => queue_resources})
    rescue => e
      all_errors.merge!({:queues => e.message})
      all_resources.merge!({:queues => {}})
    end
  end
  
  def self.get_dependencies(resource, all_resources)
    queue_policies = []
    if all_resources[:queue_policies]
      all_resources[:queue_policies].each do |policy|
        queue_policies.push(policy) if resource[:name] == policy[:name]
      end      
    end
    return { :queue_policies => queue_policies }
  end

  def self.ResourceName(resource)
    return "queue" + resource[:name].tr('^A-Za-z0-9', '') 
  end
  
  def self.OutputList(resource)
    return {"Queue URL" => "URL,Ref",
            "Queue ARN" => "QueueARN,GetAtt,Arn",
            "Queue Name" => "QueueName,GetAtt,QueueName"}
  end
  
  def initialize(resource)
    @name = Queues.ResourceName(resource)
    super(@name, "AWS::SQS::Queue")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"DelaySeconds" => resource[:delay_seconds].to_s}) if resource[:delay_seconds]
    props.merge!({"MaximumMessageSize" => resource[:maximum_message_size].to_s}) if resource[:maximum_message_size]
    props.merge!({"MessageRetentionPeriod" => resource[:message_retention_period].to_s}) if resource[:message_retention_period]
    props.merge!({"ReceiveMessageWaitTimeSeconds" => resource[:receive_message_wait_timeout_seconds].to_s}) if resource[:receive_message_wait_timeout_seconds]
    props.merge!({"VisibilityTimeout" => resource[:visibility_timeout].to_s}) if resource[:visibility_timeout]

    if resource[:redrive_policy]
      redrive_policy = {}
      redrive_policy["maxReceiveCount"] = resource[:redrive_policy]["maxReceiveCount"] if resource[:redrive_policy]["maxReceiveCount"]
      redrive_policy["deadLetterTargetArn"] = ref_or_getatt(:queues, resource[:redrive_policy]["deadLetterTargetArn"], :queue_arn, "Arn", template, name_mappings) if resource[:redrive_policy]["deadLetterTargetArn"]
      props.merge!({"RedrivePolicy" => redrive_policy}) if redrive_policy
    end

    return @cf_definition.deep_merge({ Queues.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props}}) 
  end
    
end
