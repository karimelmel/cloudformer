require 'open-uri'

class TemplatesController < ApplicationController

  http_basic_authenticate_with :name => USER_NAME, :password => PASSWORD

  def extract_resource(resource_type, template, name_mappings)
    retResources = {}
    if template.selected_resources[resource_type]
      template.selected_resources[resource_type].each do |resource|
        cf_definition = Object::const_get(template.resource_metadata[resource_type][:template_converter]).new(resource)
        retResources = retResources.merge(cf_definition.convert(resource, template, name_mappings))
      end
    end
    return retResources
  end

  def extract_outputs(resource_name, attributes, name_mappings)
    retOutputs = {}
    if !attributes.empty?
      actualName = CF_converter.map_resource_name(resource_name, name_mappings)
      attributes.each do |attr|
        pieces = attr.split(",")
        if pieces[1].eql?("Ref")
          retOutputs.merge!({"#{actualName}#{pieces[0]}" => { "Value" => { "Ref" => actualName }}})
        elsif pieces[1].eql?("GetAtt")
          retOutputs.merge!({"#{actualName}#{pieces[0]}" => { "Value" => { "Fn::GetAtt" => [actualName, pieces[2]] }}})
        elsif pieces[1].eql?("Join")
          join_list = []
          join_array = pieces[3,pieces.length() - 3]
          while elem = join_array.shift()
            if elem.eql?("Ref")
              join_list.push({ "Ref" => actualName})
            elsif elem.eql?("GetAtt")
              join_list.push({ "Fn::GetAtt" => [actualName, join_array.shift()] })
            else
              join_list.push("#{elem}")
            end
          end
          retOutputs.merge!({"#{actualName}#{pieces[0]}" => { "Value" => { "Fn::Join" => [ "#{pieces[2]}", join_list]}}})
        end
      end
    end
    return retOutputs
  end

  def merge_selected_resources(current, additional)
    newlist = current
    if !additional.empty?
      additional.each do |rtype, rlist|
        if !newlist[rtype]
          newlist.merge!({rtype => rlist})
        else
          rlist.each do |ritem|
            newlist[rtype] << ritem
          end
        end
      end
    end
    return newlist
  end

  def get_resource_name_mappings(selected_resources, params)
    template = Template.new()
    name_mappings = {}
    selected_resources.each_pair do |resource_name, resource_list|
      if template.resource_metadata[resource_name][:template_section] == :resources
        resource_list.each do |resource|
          name_mappings.merge!({Object::const_get(template.resource_metadata[resource_name][:template_converter]).ResourceName(resource) => params["templatename_#{Object::const_get(template.resource_metadata[resource_name][:template_converter]).ResourceName(resource)}"]})
        end
      end
    end
    return name_mappings
  end

  def get_resource_outputs(selected_resources, params)
    template = Template.new()
    outputs = {}
    selected_resources.each_pair do |resource_name, resource_list|
      if template.resource_metadata[resource_name][:template_section] == :resources
        resource_list.each do |resource|
          outputs.merge!({Object::const_get(template.resource_metadata[resource_name][:template_converter]).ResourceName(resource) =>
            params["outputs_#{Object::const_get(template.resource_metadata[resource_name][:template_converter]).ResourceName(resource)}"]}) if
              params["outputs_#{Object::const_get(template.resource_metadata[resource_name][:template_converter]).ResourceName(resource)}"]
        end
      end
    end
    return outputs
  end

  def store_credentials
    session[:aws_access_key_id] = params[:access_key]
    session[:aws_secret_access_key] = params[:secret_key]

    respond_to do |format|
      format.html { render :template => "templates/index" }
    end
  end


  # GET /templates
  # GET /templates.xml
  def index
    @CloudFormer_Version = "0.41 (Beta)"

    myRegion = "us-west-2"
    begin
      client = HTTPClient.new
      myAZ = client.get_content("http://169.254.169.254/latest/meta-data/placement/availability-zone")
      myRegion = myAZ.chop
    rescue => e
      p e.message
      p "Could not find the Availability Zone for this EC2 instance"
    end

    session[:region] = myRegion if !session[:region]
    if myRegion.eql?("us-gov-west-1")
      session[:region_list] = {
        "GovCloud (US)" => "us-gov-west-1"
      }
    elsif myRegion.eql?("cn-north-1")
      session[:region_list] = {
        "China (Beijing)" => "cn-north-1"
      }
    elsif myRegion.eql?("cn-northwest-1")
      session[:region_list] = {
        "China (Ningxia)" => "cn-northwest-1"
      }
    else
      session[:region_list] = {
        "US East (Virginia)" => "us-east-1",
        "US East (Ohio)" => "us-east-2",
        "US West (Oregon)" => "us-west-2",
        "US West (N. California)" => "us-west-1",
        "EU West (Ireland)" => "eu-west-1",
        "EU (London)" => "eu-west-2",
        "EU (Paris)" => "eu-west-3",
        "EU (Frankfurt) Region" => "eu-central-1",
        "Canada (Central)" => "ca-central-1",
        "Asia Pacific (Singapore)" => "ap-southeast-1",
        "Asia Pacific (Tokyo)" => "ap-northeast-1",
        "Asia Pacific (Seoul)" => "ap-northeast-2",
        "Asia Pacific (Osaka-Local)" => "ap-northeast-3",
        "Asia Pacific (Sydney)" => "ap-southeast-2",
        "Asia Pacific (Mumbai)" => "ap-south-1",
        "South America (Sao Paulo)" => "sa-east-1"
      }
    end

    if session[:aws_access_key_id]
      respond_to do |format|
        format.html # index.html.erb
      end
    else
      begin
        userdata = JSON.parse(open('/home/ec2-user/credentials').read)
      rescue
        userdata = {}
      ensure
        session[:aws_access_key_id] = userdata["aws_access_key_id"] if userdata["aws_access_key_id"]
        session[:aws_secret_access_key] = userdata["aws_secret_access_key"] if userdata["aws_secret_access_key"]
        respond_to do |format|
          format.html # index.html.erb
        end
      end
    end
  end

  # GET /templates/new
  # GET /templates/new.xml
  def new
    begin
      @template = Template.new()
      @template.current_step = session[:template_step]

      session[:region] = params[:region_name] if params[:region_name]
      if session[:aws_access_key_id] && session[:aws_access_key_id] != ""
        # We need the following two config lines to use the two versions of the ruby APIs, in the future we should update this web app to just call the new version.
        AWS.config({ :access_key_id => session[:aws_access_key_id], :secret_access_key => session[:aws_secret_access_key], :user_agent_prefix => "aws-cloudformer"})
        Aws.config({ :access_key_id => session[:aws_access_key_id], :secret_access_key => session[:aws_secret_access_key], :user_agent_prefix => "aws-cloudformer"})
      else
        AWS.config({:user_agent_prefix => "aws-cloudformer"})
      end

      if @template.first_step?

        @template.all_resources = {}
        @template.all_errors = {}
        @template.selected_resources = {}

        @template.steps.each do |step|
          @template.resources_for_step[step].each do |resource|
            if @template.resource_metadata[resource][:template_section] == :resources
              Object::const_get(@template.resource_metadata[resource][:template_converter]).LoadResources(@template.all_resources, session[:aws_access_key_id], session[:aws_secret_access_key], session[:region], @template.all_errors)
            end
          end
        end

        @template.steps.each do |step|
          @template.resources_for_step[step].each do |resource|
            if @template.resource_metadata[resource][:template_section] == :resources &&
              Object::const_get(@template.resource_metadata[resource][:template_converter]).post_load(@template, session[:region])
            end
          end
        end
      end

      session[:selected_resources] = @template.selected_resources
      session[:all_resources] = @template.all_resources
      session[:all_errors] = @template.all_errors
      session[:outputs] = {}

      @all = session[:all_resources]
      # @debug = true

      respond_to do |format|
        format.html # new.html.erb
      end
    rescue => e
      respond_to do |format|
        p "+----------------"
        p e.message
        p "+----------------"
        format.html { redirect_to("/loadfailed", :notice => 'Template save failed.') }
      end
    end
  end

  # POST /templates
  # POST /templates.xml
  def create

    # Recreate the template from the session and the parameters
    session[:selected_resources] = params[:selected_resources] if params[:selected_resources]
    @template = Template.new
    @template.current_step  = session[:template_step]
    @template.all_resources = session[:all_resources]
    @template.all_errors = session[:all_errors]
    @template.selected_resources = eval(session[:selected_resources]) || {}

    @all = session[:all_resources]
    # @debug = true

    # Include anything that was selected or filled in
    @template.resources_for_step[@template.current_step].each do |resource|

      dependent_resources = {}
      selected_resources = {}

      if @template.resource_metadata[resource][:resource_type] == :text
        selected_resources = { resource => params["input_#{resource}"]} if !@template.resource_metadata[resource][:template_section].eql?(:none)
        if @template.resource_metadata[resource][:template_converter]
          @template[:selected_resources] = merge_selected_resources(@template[:selected_resources], Object::const_get(@template.resource_metadata[resource][:template_converter]).get_dependencies(params["input_#{resource}"], @template[:all_resources]))
        end
      elsif @template.resource_metadata[resource][:resource_type] == :option
        selected_resources = { resource => params["input_#{resource}"]} if !@template.resource_metadata[resource][:template_section].eql?(:none)
        if @template.resource_metadata[resource][:template_converter]
          @template[:selected_resources] = merge_selected_resources(@template[:selected_resources], Object::const_get(@template.resource_metadata[resource][:template_converter]).get_dependencies(params["input_#{resource}"], @template[:all_resources]))
        end
      elsif @template.resource_metadata[resource][:resource_type] == :checkbox && params["input_#{resource}"]
        exploded_array = []
        params["input_#{resource}"].each do |item|
          exploded_array << eval(item)
          if @template.resource_metadata[resource][:template_converter]
            @template[:selected_resources] = merge_selected_resources(@template[:selected_resources], (Object::const_get(@template.resource_metadata[resource][:template_converter]).get_dependencies(eval(item), @template[:all_resources])))
          end
        end
        selected_resources = { resource => exploded_array }  if !@template.resource_metadata[resource][:template_section].eql?(:none)
      end

      # Replace any resources of the specific type with the actual selected set
      @template[:selected_resources].delete(resource)
      @template[:selected_resources].merge!(selected_resources) if selected_resources

    end

    # Navigate as required
    if params["back_button.x"]
      @template.previous_step
    elsif @template.last_step?
      # we're at the end
    else
      @template.next_step
    end

    session[:template_step] = @template.current_step

    respond_to do |format|
      if params["cancel_button.x"]
        session[:selected_resources] = session[:all_errors] = session[:all_resources] = session[:template_step] = session[:name_mappings] = nil
        format.html { redirect_to("/", :notice => 'Template creation was canceled.') }
      elsif @template.last_step?
        session[:name_mappings] = get_resource_name_mappings(eval(session[:selected_resources]), params)
        session[:outputs] = get_resource_outputs(eval(session[:selected_resources]), params)
        format.html { redirect_to("/templates/show", :notice => 'Template was successfully created.') }
      else
        format.html { render :action => "new" }
      end
    end
  end

  def show
    @json_template = {
      "AWSTemplateFormatVersion" => "2010-09-09",
      "Resources" => {}
    }

    template = Template.new
    template.selected_resources = eval(session[:selected_resources])
    template.all_resources = session[:all_resources]
    template.all_errors = session[:all_errors]

    template.steps.each do |step|
      template.resources_for_step[step].each do |resource|
        if template.resource_metadata[resource][:template_section] == :resources
          if template.resource_metadata[resource][:template_converter]
            Object::const_get(template.resource_metadata[resource][:template_converter]).post_selection(template)
          end
        end
      end
    end

    # Re-consitute the user input and then build the CloudFormation template
    @json_template["Description"] = template.selected_resources[:description] if template.selected_resources[:description]

    template.steps.each do |step|
      template.resources_for_step[step].each do |resource|
        if template.resource_metadata[resource][:template_section] == :resources
          @json_template["Resources"].merge!(self.extract_resource(resource, template, session[:name_mappings]))
        end
      end
    end

    outputs = {}
    session[:outputs].each do |resource_name, attributes|
      outputs.merge!(self.extract_outputs(resource_name, attributes, session[:name_mappings]))
    end
    @json_template.merge!({"Outputs" => outputs}) if !outputs.empty?

    # Setup for a save
    session[:json_template] = @json_template
    bucket_list = []
    if template.all_resources && template.all_resources[:buckets]
      template.all_resources[:buckets].each do |bucket|
        bucket_list.push([bucket[:display_name], bucket[:name]])
      end
    end
    session[:bucket_list] = bucket_list

    # Ok, we're done
    session[:all_errors] = session[:selected_resources] = session[:all_resources] = session[:template_step] = session[:name_mappings] = nil

    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def save
    success = true
    failure_message = ""

    region_endpoints = {
      nil => "s3.amazonaws.com",
      "us-east-1" => "s3.amazonaws.com",
      "EU" => "s3-eu-west-1.amazonaws.com",
      "eu-west-1" => "s3-eu-west-1.amazonaws.com",
      "eu-west-2" => "s3-eu-west-2.amazonaws.com",
      "eu-west-3" => "s3-eu-west-3.amazonaws.com",
      "eu-central-1" => "s3.eu-central-1.amazonaws.com",
      "us-west-1" => "s3-us-west-1.amazonaws.com",
      "us-west-2" => "s3-us-west-2.amazonaws.com",
      "ap-southeast-1" => "s3-ap-southeast-1.amazonaws.com",
      "ap-southeast-2" => "s3-ap-southeast-2.amazonaws.com",
      "ap-south-1" => "s3.ap-south-1.amazonaws.com",
      "us-east-2" => "s3.us-east-2.amazonaws.com",
      "ca-central-1" => "s3.ca-central-1.amazonaws.com",
      "ap-northeast-1" => "s3-ap-northeast-1.amazonaws.com",
      "ap-northeast-2" => "s3-ap-northeast-2.amazonaws.com",
      "ap-northeast-3" => "s3-ap-northeast-3.amazonaws.com",
      "sa-east-1" => "s3-sa-east-1.amazonaws.com",
      "cn-north-1" => "s3.cn-north-1.amazonaws.com.cn",
      "cn-northwest-1" => "s3.cn-northwest-1.amazonaws.com.cn",
      "us-gov-west-1" => "s3-us-gov-west-1.amazonaws.com"
    }
    region_name = {
      nil => "us-east-1",
      "us-east-1" => "us-east-1",
      "EU" => "eu-west-1",
      "us-west-1" => "us-west-1",
      "eu-west-1" => "eu-west-1",
      "eu-west-2" => "eu-west-2",
      "eu-west-3" => "eu-west-3",
      "eu-central-1" => "eu-central-1",
      "us-west-2" => "us-west-2",
      "ap-southeast-1" => "ap-southeast-1",
      "ap-southeast-2" => "ap-southeast-2",
      "ap-south-1" => "ap-south-1",
      "us-east-2" => "us-east-2",
      "ca-central-1" => "ca-central-1",
      "ap-northeast-1" => "ap-northeast-1",
      "ap-northeast-2" => "ap-northeast-2",
      "ap-northeast-3" => "ap-northeast-3",
      "sa-east-1" => "sa-east-1",
      "cn-north-1" => "cn-north-1",
      "cn-northwest-1" => "cn-northwest-1",
      "us-gov-west-1" => "us-gov-west-1"
    }

    begin
      s3_global = AWS::S3.new(:s3_endpoint => region_endpoints[session[:region]])
      bucket_location = s3_global.client.get_bucket_location(:bucket_name => params[:bucket_name]).data[:location_constraint]
      bucket_server = region_endpoints[bucket_location]
      bucket_region = region_name[bucket_location]
      bucket_endpoint = AWS::S3.new(:s3_endpoint => bucket_server)

      @launch_url = "https://console.aws.amazon.com/cloudformation/home?region=#{bucket_region}#cstack=sn~CloudFormerLaunchedStack|turl~https://#{bucket_server}/#{params[:bucket_name]}/#{params[:template_name]}"

      bucket_endpoint.client.put_object(:bucket_name => params[:bucket_name], :key => params[:template_name], :data => JSON.pretty_generate(session[:json_template]))
    rescue => e
      failure_message = e.message
      p "+++++++++++++++"
      p failure_message
      p "+++++++++++++++"
      success = false
    ensure
      respond_to do |format|
        if params["cancel_button.x"]
          session[:bucket_list] = session[:json_template] = nil
          format.html { redirect_to("/", :notice => 'Template save was canceled.') }
        elsif success
          format.html # save.html.erb
        else
          format.html { redirect_to("/savefailed", :notice => 'Template save failed: (#{failure_message}).') }
        end
      end
    end
  end

end
