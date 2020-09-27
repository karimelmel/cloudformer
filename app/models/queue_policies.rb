class Queue_Policies < CF_converter
  
  attr_accessor :name

  @@policy_id = 1
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)

    begin
      # Get all the SQS queues we care about
      sqs = AWS::SQS.new(:region => region)
      queue_policies = []
      sqs.queues.each do |queue|
        attr = sqs.client.get_queue_attributes({:queue_url => queue.url, :attribute_names => ["Policy"]})[:attributes]
        nameparts = queue.url.split("/")
        queue_policies << {:name => nameparts.last, :display_name => "Queue policy for #{nameparts.last}", :policy => attr["Policy"]} if attr["Policy"]
      end
      all_resources.merge!({:queue_policies => queue_policies})
    rescue => e
      all_errors.merge!({:queue_policies => e.message})
      all_resources.merge!({:queue_policies => {}})
    end
  end

  def self.ResourceName(resource)
    return "sqspolicy" + resource[:name].tr('^A-Za-z0-9', '') 
  end

  def initialize(resource)
    @name = Queue_Policies.ResourceName(resource)
    super(@name, "AWS::SQS::QueuePolicy")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"Queues" => [ref_or_literal(:queues, resource[:name], template, name_mappings)]}) if resource[:name]
    document = JSON.load(resource[:policy])
    document["Statement"].each do |statement|
       statement["Resource"] = ref_or_getatt(:queues, resource[:name], :name, "Arn", template, name_mappings)
    end if document["Statement"]
    props.merge!({"PolicyDocument" => document}) if resource[:policy]
    return @cf_definition.deep_merge({ Queue_Policies.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
