class Security_Groups < CF_converter
  
  @@ingres_type_count = 0
  attr_accessor :name
  
  def self.LoadResources(all_resources, aws_access_key_id, aws_secret_access_key, region, all_errors)
    begin
      # Get all the security groups resources we care about
      ec2 = AWS::EC2.new(:region => region)
      all_security_groups = ec2.client.describe_security_groups().data[:security_group_info]
      valid_security_groups = []
      all_security_groups.each do |sg|
        if sg[:group_name].match(/^AWS-OpsWorks-/) && sg[:group_description].match(/- do not change or delete/)
          # This is a default OpsWorks SG so remove it
        elsif sg[:vpc_id]
          sg.merge!({:fake_id => sg[:group_id]})
          valid_security_groups << sg
        else
          sg.merge!({:fake_id => sg[:group_name]})
          valid_security_groups << sg
        end
      end if all_security_groups
      all_resources.merge!({:security_groups => valid_security_groups})
    rescue => e
      all_errors.merge!({:security_groups => e.message})
      all_resources.merge!({:security_groups => {}})
    end
  end

  def self.ResourceName(resource)
    return "sg" + resource[:group_name].tr('^A-Za-z0-9', '')
  end
  
  def initialize(resource)
    @name = Security_Groups.ResourceName(resource)
    super(@name, "AWS::EC2::SecurityGroup")
  end
  
  def self.get_resource_attributes(resource)
    tags = ""
    vpc = ""
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags = tags + "\n" + "#{tag[:key]}: #{tag[:value]} "
      end
    end          
    if resource[:vpc_id]
      vpc = "\n" + resource[:vpc_id]
    end
    return "Description: #{resource[:group_description]} " + vpc + tags
  end  

  def self.OutputList(resource)
    return {"Security Group Name" => "Name,Ref",
            "Security Group Id" => "GroupId,GetAtt,GroupId"}
  end

  def convert(resource, template, name_mappings)

    props = {}
    props.merge!({"GroupDescription" => resource[:group_description]}) if resource[:group_description]
    props.merge!({"VpcId" => ref_or_literal(:vpcs, resource[:vpc_id], template, name_mappings)}) if resource[:vpc_id]

    tags = []
    if resource[:tag_set]
      resource[:tag_set].each do |tag|
        tags.push({"Key" => tag[:key], "Value" => tag[:value]}) if tag[:value] != nil && !tag[:key].starts_with?("aws:")
      end
    end          
    props.merge!({"Tags" => tags}) if !tags.empty?      

    return @cf_definition.deep_merge({ Security_Groups.map_resource_name(@name, name_mappings) => { "Type" => @cf_type, "Properties" => props }})
  end
    
end
