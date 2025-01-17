# Common use of docker::run
define sunet::docker_run(
  String $image,
  String $imagetag           = hiera('sunet_docker_default_tag', 'latest'),
  Array[String] $volumes     = [],
  Array[String] $ports       = [],
  Array[String] $expose      = [],
  Array[String] $env         = [],
  String $net                = hiera('sunet_docker_default_net', 'docker'),
  Optional[String] $command  = undef,
  Optional[String] $hostname = undef,
  $depends                   = [],  # should be array of strings, but need to fix usage first
  $start_on                  = [],    # deprecated, used with 'depends' for compatibility
  $stop_on                   = [],    # currently not used, kept for compatibility
  Array[String] $dns         = [],
  $before_start              = undef, # command executed before starting
  $before_stop               = undef, # command executed before stopping
  $after_start               = undef, # command executed before starting
  $after_stop                = undef, # command executed before stopping
  Boolean $use_unbound       = false, # deprecated, kept for compatibility
  String $ensure             = 'present',
  $extra_parameters          = [],  # should be array of strings, but need to fix usage first
  Hash[String, String] $extra_systemd_parameters = {},
  Boolean $uid_gid_consistency = true,
  Boolean $fetch_docker_image  = true,
) {
  if $use_unbound {
    warning('docker-unbound is deprecated, container name resolution should continue to work using docker network with DNS')
  }

  if $uid_gid_consistency {
    $_uid_gid = [
      '/etc/passwd:/etc/passwd:ro',  # uid consistency
      '/etc/group:/etc/group:ro',    # gid consistency
    ]
  } else { $_uid_gid = [] }

  # Use start_on for docker::run $depends, unless the new argument 'depends' is given
  $_depends = $depends ? {
    []      => any2array($start_on),
    default => flatten([$depends]),
  }

  # If a non-default network is used, make sure it is created before this container starts
  $req = $net ? {
    'host'   => [],
    'bridge' => [],
    default  => [Docker_network[$net]],
  }

  $image_tag = "${image}:${imagetag}"
  if $fetch_docker_image {
    docker::image { "${name}_${image_tag}" :  # make it possible to use the same docker image more than once on a node
      image   => $image_tag,
      require => Class['sunet::dockerhost'],
    }
  }

  docker::run { $name :
    ensure                   => $ensure,
    volumes                  => flatten([$volumes, $_uid_gid]),
    hostname                 => $hostname,
    ports                    => $ports,
    expose                   => $expose,
    env                      => $env,
    net                      => $net,
    command                  => $command,
    dns                      => $dns,
    depends                  => $_depends,
    require                  => flatten([$req]),
    before_start             => $before_start,
    before_stop              => $before_stop,
    after_start              => $after_start,
    after_stop               => $after_stop,
    docker_service           => true,  # the service 'docker' is maintainer by puppet, so depend on it
    image                    => $image_tag,
    extra_parameters         => flatten([$extra_parameters]),
    extra_systemd_parameters => $extra_systemd_parameters,
  }

  # Remove the upstart file created by earlier versions of garethr-docker
  exec { "remove_docker_upstart_job_${name}":
    command => "/bin/rm /etc/init/docker-${name}.conf",
    onlyif  => "/usr/bin/test -f /etc/init/docker-${name}.conf",
  }
}
