Chef Metal
==========

This library solves the problem of repeatably creating machines and infrastructures in Chef.  It has a plugin model that lets you write drivers for your favorite infrastructures, including VirtualBox, EC2, LXC, bare metal, and many more!

Currently, chef-metal supports Vagrant (VirtualBox and VMWare), Fog (EC2, Openstack, DigitalOcean), LXC, Docker, Unixes/ssh, and Windows/winrm with real chef-servers or with automagical chef-zero tunneling.  Further out, we'd like to extend support to image factories (using the machine resource to produce images) and PXE support.

Try It Out
----------

To give it a spin, get chef 11.8 or greater try this:

    git clone https://github.com/opscode/cheffish.git
    cd cheffish
    rake install
    cd ..

    git clone https://github.com/opscode/chef-metal.git
    cd chef-metal
    rake install

    cd chef-metal
    chef-client -z -o myapp::vagrant,myapp::linux,myapp::small

This will create two vagrant precise64 linux boxes, "mario" and "luigi1", in `~/machinetest`, bootstrapped to an empty runlist.  For Windows, you can replace `myapp::linux` with `myapp::windows`, but you'll need your own Windows vagrant box to do that (licensing!).

What Is Chef Metal?
-------------------

Chef Metal has two major abstractions: the machine resource, and drivers.

### The `machine` resource

You declare what your machines do (recipes, tags, etc.) with the `machine` resource, the fundamental unit of Chef Metal.  You will typically declare `machine` resources in a separate, OS/driver-independent file that declares the *topology* of your app--your machines and the recipes that will run on them.

The machine resources from the example [myapp::small](https://github.com/opscode/chef-metal/blob/master/cookbooks/myapp/recipes/small.rb) are pretty straightforward.  Here's a copy/paste:

```ruby
machine 'mario' do
  recipe 'postgresql'
  recipe 'mydb'
  tag 'mydb_master'
end

num_webservers = 1

1.upto(num_webservers) do |i|
  machine "luigi#{i}" do
    recipe 'apache'
    recipe 'mywebapp'
  end
end
```

You will notice the dynamic nature of the number of web servers.  It's all code, your imagination is the limit :)

Kitchen
-------

Chef Metal also works with Test Kitchen, allowing you to test entire clusters, not just machines!  The repository for the kitchen-metal gem is https://github.com/doubt72/kitchen-metal.

Drivers
-------

Drivers handle the real work of getting those abstract definitions into real, physical form.  They handle the following tasks, idempotently (you can run the resource again and again and it will only create the machine once--though it may notice things are wrong and fix them!):

* Allocating machines from the cloud, creating containers or VMs, or grabbing bare metal
* Connecting to those machines via ssh, winrm, or other transports
* Bootstrapping chef onto the machines and converging the recipes you suggested

The [driver API](https://github.com/opscode/chef-metal/blob/master/lib/chef_metal/driver.rb) is separated out so that new drivers can be made with minimal effort (without having to rewrite ssh, tunneling, bootstrapping, and OS support).  But to the user, they appear as a single thing, so that the machine acquisition can use its smarts to autodetect the other bits (transports, OS's, etc.).

Drivers save their data in the Chef node itself, so that they will be accessible to everyone who is using the Chef server to manage the nodes.

Drivers each have their own repository.  Current drivers:

**Cloud:**
- [FOG: EC2, DigitalOcean, OpenStack, etc.](https://github.com/opscode/chef-metal-fog)

**Virtualization:**
- [Vagrant: VirtualBox, VMWare Fusion, etc.](https://github.com/opscode/chef-metal-vagrant)

**Containers:**
- [LXC](https://github.com/opscode/chef-metal-lxc)
- [Docker](https://github.com/opscode/chef-metal-docker)

**Bare Metal:**
- [SSH (no PXE)](https://github.com/double-z/chef-metal-ssh)

### Vagrant

chef-zero comes with a driver for Vagrant, an abstraction that covers VirtualBox, VMWare and other Virtual Machine providers. To run it, you can check out the sample recipes with:

```
chef-client -z -o myapp::vagrant,myapp::linux,myapp::small
```

The driver specification is in myapp::vagrant and myapp::linux [sample recipes](https://github.com/opscode/chef-metal/tree/master/cookbooks/myapp/recipes), copy/pasted here for your convenience:

```ruby
vagrant_cluster "#{ENV['HOME']}/machinetest"

directory "#{ENV['HOME']}/machinetest/repo"
with_chef_local_server :chef_repo_path => "#{ENV['HOME']}/machinetest/repo"

vagrant_box 'precise64' do
  url 'http://files.vagrantup.com/precise32.box'
end
```

`vagrant_cluster` declares a directory where all the vagrant definitions will be stored, and uses `with_driver` internally to tell Chef Metal that this is the driver we want to use for machines.

`vagrant_box` makes sure a particular vagrant box exists, and lets you specify `driver_options` for things like port forwarding, OS definitions, and any other vagrant-isms.  A more complicated vagrant box, with driver options, can be found in [myapp::windows](https://github.com/opscode/chef-metal/blob/master/cookbooks/myapp/recipes/windows.rb).

`with_chef_local_server` is a generic directive that creates a chef-zero server pointed at the given repository.  nodes, clients, data bags, and all data will be stored here on your provisioner machine if you do this.  You can use `with_chef_server` instead if you want to point at OSS, Hosted or Enterprise Chef, and if you don't specify a Chef server at all, it will use the one you are running chef-client against. Keep in mind when using `with_chef_server` and running `chef-client -z` on your workstation that you will also need to set the client name and signing key for the chef server. If you've already got knife.rb set up, then something like this will correctly create a client for the chef server on instance using your knife.rb configuration:

```ruby
require 'chef/config'

with_chef_server "https://chef-server.example.org", {
  :client_name => Chef::Config[:node_name],
  :signing_key_filename => Chef::Config[:client_key]
}
```

Typically, you declare these in separate files from your machine resources.  Chef Metal picks up the drivers you have declared, and uses them to instantiate the machines you request.  The actual machine definitions, in this case, are in `myapp::small`, and are generic--you could use them against EC2 as well:

```ruby
machine 'mario' do
  recipe 'postgresql'
  recipe 'mydb'
  tag 'mydb_master'
end

num_webservers = 1

1.upto(num_webservers) do |i|
  machine "luigi#{i}" do
    recipe 'apache'
    recipe 'mywebapp'
  end
end
```

### Fog (EC2 and friends)

chef-metal also comes with a [Fog](http://fog.io/) driver that handles provisioning to Amazon's EC2 and other cloud providers.  (Only EC2 has been tested so far.)  Before you begin, you will need to put your AWS credentials in ~/.aws/config in the format [mentioned in Option 1 here](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#d0e726).

Once your credentials are in, basic usage looks like this:

```
chef-client -z -o myapp::ec2,myapp::small
```

The driver definition in `myapp::ec2` looks like this:

```ruby
ec2testdir = File.expand_path('~/ec2test')

directory ec2testdir

with_fog_ec2_driver # :provider => 'AWS'

with_machine_options :image_id => 'ami-5ee70037'

fog_key_pair 'me' do
  private_key_path "#{ec2testdir}/me"
  public_key_path "#{ec2testdir}/me.pub"
end
```

`with_fog_ec2_driver` tells chef-metal to use the Fog driver against EC2.  If you specify your credentials in `~/.aws/config`, you don't *have* to specify anything else; it will use the Fog defaults.  You may pass a hash of parameters to `with_fog_ec2_driver` that is described [here](https://github.com/opscode/chef-metal-fog/blob/master/lib/chef_metal_fog/fog_driver.rb#L21-L32).

`fog_key_pair` creates a new key pair (if the files do not already exist) and automatically tells the driver to use it to bootstrap subsequent machines.  The private/public key pair will be automatically authorized to log on to the instance on first boot.

To pass options like ami, you can say something like this:

```ruby
with_machine_options :image_id => 'ami-5ee70037'
```

If you need to pass bootstrapping options on a per-machine basis, you can do that as well by doing something like the following:

```ruby
machine "Ubuntu_64bit" do
  action :create
  machine_options 'bootstrap_options' => {
    'image_id' => 'ami-59a4a230',
    'flavor_id' => 't1.micro'
  }
end
```

You will notice that we are still using `myapp::small` here.  Machine definitions are generally driver-independent.  This is an important feature that allows you to spin up your clusters in different places to create staging, test or miniature dev environments.

Bugs and The Plan
-----------------

It's early days.  *Please* submit bugs at https://github.com/opscode/chef-metal/issues, contact jkeiser on Twitter at @jkeiser2, email at jkeiser@opscode.com

If you are interested in the Plan for Chef Metal, you can peruse our [Trello board](https://trello.com/b/GcSzW0GM/chef-metal)!  Please add suggestions there, vote or comment on issues that are important to you, and feel free to contribute by picking up a card.  Chat with me (jkeiser@opscode.com) if you would like some context on how to go about implementing a card, or just go hog wild and submit a PR :)
