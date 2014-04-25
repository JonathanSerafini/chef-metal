require 'chef/resource/lwrp_base'
require 'cheffish'
require 'chef_metal'

class Chef::Resource::Machine < Chef::Resource::LWRPBase
  self.resource_name = 'machine'

  def initialize(*args)
    super
    @chef_environment = Cheffish.current_environment
    @chef_server = Cheffish.current_chef_server
    @provisioner = ChefMetal.current_driver
    @machine_options = ChefMetal.current_machine_options
    if ChefMetal.current_machine_batch
      ChefMetal.current_machine_batch.machines << self
    end
  end

  def after_created
    # Notify the provisioner of this machine's creation
    @provisioner.resource_created(self)
  end

  actions :create, :delete, :stop, :converge, :nothing
  default_action :create

  # Provisioner attributes
  attribute :provisioner
  attribute :machine_options

  # Node attributes
  Cheffish.node_attributes(self)

  # Client keys
  # Options to generate private key (size, type, etc.) when the server doesn't have it
  attribute :private_key_options, :kind_of => String

  # Optionally pull the public key out to a file
  attribute :public_key_path, :kind_of => String
  attribute :public_key_format, :kind_of => String

  # If you really want to force the private key to be a certain key, pass these
  attribute :source_key
  attribute :source_key_path, :kind_of => String
  attribute :source_key_pass_phrase

  # Client attributes
  attribute :admin, :kind_of => [TrueClass, FalseClass]
  attribute :validator, :kind_of => [TrueClass, FalseClass]

  # Client Ohai hints, allows machine to enable hints
  # e.g. ohai_hint 'ec2' => { 'a' => 'b' } creates file ec2.json with json contents { 'a': 'b' }
  attribute :ohai_hints, :kind_of => Hash

  # Allows you to turn convergence off in the :create action by writing "converge false"
  # or force it with "true"
  attribute :converge, :kind_of => [TrueClass, FalseClass]

  # A list of files to upload, in the format REMOTE_PATH => LOCAL_PATH|HASH.
  # == Examples
  # files '/remote/path.txt' => '/local/path.txt'
  # files '/remote/path.txt' => { :local_path => '/local/path.txt' }
  # files '/remote/path.txt' => { :content => 'woo' }
  attribute :files, :kind_of => Hash

  # A single file to upload, in the format REMOTE_PATH, LOCAL_PATH|HASH.
  # This directive may be passed multiple times, and multiple files will be uploaded.
  # == Examples
  # file '/remote/path.txt', '/local/path.txt'
  # file '/remote/path.txt', { :local_path => '/local/path.txt' }
  # file '/remote/path.txt', { :content => 'woo' }
  def file(remote_path, local = nil)
    @files ||= {}
    if remote_path.is_a?(Hash)
      if local
        raise "file(Hash, something) does not make sense.  Either pass a hash, or pass a pair, please."
      end
      remote_path.each_pair do |remote, local|
        @files[remote] = local
      end
    elsif remote_path.is_a?(String)
      if !local
        raise "Must pass both a remote path and a local path to file directive"
      end
      @files[remote_path] = local
    else
      raise "file remote_path must be a String, but is a #{remote_path.class}"
    end
  end

  # chef client version and omnibus
  # chef-zero boot method?
  # chef-client -z boot method?
  # pushy boot method?
end
