class R53_Hostedzones < CF_converter
  
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the Route53 hosted zones we care about
      r53 = AWS::Route53.new()
      zones = r53.client.list_hosted_zones().data[:hosted_zones]
      zones.each do |zone|
        zone_detail = r53.client.get_hosted_zone({:id => zone[:id]})
        zone[:vpcs] = zone_detail[:vp_cs]
      end
      all_resources.merge!({:r53_hostedzones => zones})
    rescue => e
      if region.eql?("us-gov-west-1")
        all_errors.merge!({:r53_hostedzones => "Not supported in this region"})
      else
        all_errors.merge!({:r53_hostedzones => e.message})
      end
      all_resources.merge!({:r53_hostedzones => {}})
    end
  end

  def self.ResourceName(resource)
    return "zone" + resource[:name].tr('^A-Za-z0-9', '')
  end
  
  def self.get_resource_attributes(resource)
    desc = "Comment: #{resource[:config][:comment]}"
    if !resource[:vpcs].empty?
      resource[:vpcs].each do |vpc|
        desc += "\n#{vpc[:VPCId]} : #{vpc[:VPCRegion]}"
      end
    end if resource[:vpcs]
    return desc
  end  
  
  def self.OutputList(resource)
    return {"Hosted Zone" => "Name,Ref"}
  end

  def initialize(resource)
    @name = R53_Hostedzones.ResourceName(resource)
    super(@name, "AWS::Route53::HostedZone")
  end
  
  def convert(resource, template, name_mappings)
    props = {}

    props.merge!({"Name" => resource[:name]}) if resource[:name]

    config = {}
    config["Comment"] = resource[:config][:comment].to_s if resource[:config][:comment]
    props.merge!({"HostedZoneConfig" => config}) if ! config.empty?

    vpc_list = []
    resource[:vpcs].each do |vpc|
      vpc_list.push({"VPCId" => vpc[:vpc_id], "VPCRegion" => vpc[:vpc_region]})
    end if resource[:vpcs]
    props.merge!({"VPCs" => vpc_list}) if !vpc_list.empty?

    return @cf_definition.deep_merge({ R53_Hostedzones.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
