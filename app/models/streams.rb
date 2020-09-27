class Streams < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Streams we care about
      kinesis = AWS::Kinesis.new(:region => region)
      streams = []
      kinesis.client.list_streams().data[:stream_names].each do |stream_name|
        stream_details = kinesis.client.describe_stream({:stream_name => stream_name}).data[:stream_description]
        streams << stream_details
      end
      all_resources.merge!({:streams => streams})
    rescue => e
      if region.eql?("sa-east-1") || region.eql?("cn-north-1") || region.eql?("us-gov-west-1") || region.eql?("cn-northwest-1")
        all_errors.merge!({:streams => "Not supported in this region"})
      else
        all_errors.merge!({:streams => e.message})
      end
      all_resources.merge!({:streams => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "stream" + resource[:stream_name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    return "Name: #{resource[:stream_name]}\n" +
           "Stream ARN: #{resource[:stream_arn]}"
  end

  def self.OutputList(resource)
    return {"Stream Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Streams.ResourceName(resource)
    super(@name, "AWS::Kinesis::Stream")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"ShardCount" => resource[:shards].length.to_s()}) if resource[:shards]
    return @cf_definition.deep_merge({ Streams.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
