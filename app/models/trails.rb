class Trails < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Trails we care about
      ct = AWS::CloudTrail.new(:region => region)
      trails = []
      ct.client.describe_trails()[:trail_list].each do |trail|
        full_trail = trail.clone
        trail_details = ct.client.get_trail_status({:name => trail[:name]})
        full_trail[:is_logging] = trail_details[:is_logging]
        trails << full_trail
      end
      all_resources.merge!({:trails => trails})
    rescue => e
      all_errors.merge!({:trails => e.message})
      all_resources.merge!({:trails => {}})
    end
  end
  
  def self.ResourceName(resource)
    return "trail" + resource[:name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_dependencies(resource, all_resources)
    return {}
  end
  
  def self.get_resource_attributes(resource)
    return "Name: #{resource[:name]}"
  end

  def self.OutputList(resource)
    return {"Trail Name" => "Name,Ref"}
  end

  def initialize(resource)
    @name = Trails.ResourceName(resource)
    super(@name, "AWS::CloudTrail::Trail")
  end
  
  def convert(resource, template, name_mappings)
    props = {}
    props.merge!({"IncludeGlobalServiceEvents" => resource[:include_global_service_events]}) if resource[:include_global_service_events]
    props.merge!({"IsLogging" => resource[:is_logging].to_s()}) if resource[:is_logging]
    props.merge!({"S3KeyPrefix" => resource[:s3_key_prefix]}) if resource[:s3_key_prefix]

    props.merge!({"S3BucketName" => ref_or_literal(:buckets, resource[:s3_bucket_name], template, name_mappings)}) if resource[:s3_bucket_name]
    props.merge!({"SnsTopicName" => ref_or_literal(:topics, resource[:sns_topic_name], template, name_mappings)}) if resource[:sns_topic_name]

    return @cf_definition.deep_merge({ Trails.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
