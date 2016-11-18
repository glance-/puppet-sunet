# Install docker from https://get.docker.com/ubuntu
class sunet::dockerhost(
  $docker_version            = "1.10.3-0~${::lsbdistcodename}",
  $docker_extra_parameters   = undef,
  $run_docker_cleanup        = true,
  $docker_network            = hiera('dockerhost_docker_network', '172.18.0.0/22'),
  $docker_dns                = pick($::ipaddress_eth0, $::ipaddress_bond0, $::ipaddress_br0, $::ipaddress_em1, $::ipaddress_em2,
                                    $::ipaddress6_eth0, $::ipaddress6_bond0, $::ipaddress6_br0, $::ipaddress6_em1, $::ipaddress6_em2,
                                    $::ipaddress, $::ipaddress6,
                                    ),
  $ufw_allow_docker_dns      = true,
  $manage_dockerhost_unbound = false,
) {

  # Remove old versions, if installed
  package { ['lxc-docker-1.6.2', 'lxc-docker'] :
     ensure => 'purged',
  } ->

  file {'/etc/apt/sources.list.d/docker.list':
     ensure => 'absent',
  }


  # Add the dockerproject repository, then force an apt-get update before
  # trying to install the package. See https://tickets.puppetlabs.com/browse/MODULES-2190.
  #
  apt::source {'docker_official':
     location => 'https://apt.dockerproject.org/repo',
     release  => "ubuntu-${::lsbdistcodename}",
     repos    => 'main',
     key      => { 'id'     => '58118E89F3A912897C070ADBF76221572C52609D',
                   'server' => 'keyserver.ubuntu.net' },
     include  => { 'src' => false },
  }

  exec { 'dockerhost_apt_get_update':
     command     => '/usr/bin/apt-get update',
     cwd         => '/tmp',
     require     => Apt::Source['docker_official'],
     subscribe   => Apt::Source['docker_official'],
     refreshonly => true,
  }

  package { 'docker-engine' :
     ensure => $docker_version,
     require => Exec['dockerhost_apt_get_update'],
  }

  class {'docker':
     manage_package              => false,
     use_upstream_package_source => false,
     dns                         => $docker_dns,
     extra_parameters            => $docker_extra_parameters,
  } ->

  docker_network { 'docker':  # default network for containers
    ensure => 'present',
    subnet => $docker_network,
  }

  file {
     '/etc/logrotate.d':
      ensure  => 'directory',
      mode    => '0755',
      ;
    '/etc/logrotate.d/docker-containers':
      ensure  => file,
      path    => '/etc/logrotate.d/docker-containers',
      mode    => '0644',
      content => template('sunet/dockerhost/logrotate_docker-containers.erb'),
      ;
    }

  if $::sunet_has_nrpe_d == "yes" {
    # variables used in etc_sudoers.d_nrpe_dockerhost_checks.erb / nagios_nrpe_checks.erb
    if $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '15.04') >= 0 {
      $check_docker_containers_args = '--systemd'
    } else {
      $check_docker_containers_args = '--init_d'
    }

    file {
      '/etc/sudoers.d/nrpe_dockerhost_checks':
        ensure  => file,
        mode    => '0440',
        content => template('sunet/dockerhost/etc_sudoers.d_nrpe_dockerhost_checks.erb'),
        ;
      '/etc/nagios/nrpe.d/sunet_dockerhost_checks.cfg':
        ensure  => 'file',
        content => template('sunet/dockerhost/nagios_nrpe_checks.erb'),
        notify  => Service['nagios-nrpe-server'],
        ;
      '/usr/local/bin/check_docker_containers':
        ensure  => file,
        mode    => '0755',
        content => template('sunet/dockerhost/check_docker_containers.erb'),
        ;
    }
  }

  if $run_docker_cleanup {
    # Cron job to remove old unused docker images
    file {
      '/usr/local/bin/docker-cleanup':
        ensure  => 'file',
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => template('sunet/dockerhost/docker-cleanup.erb'),
        ;
    } ->
    sunet::scriptherder::cronjob { 'dockerhost_cleanup':
      cmd           => '/usr/local/bin/docker-cleanup',
      special       => 'daily',
      ok_criteria   => ['exit_status=0', 'max_age=25h'],
      warn_criteria => ['exit_status=0', 'max_age=49h'],
    }
  }

  if $ufw_allow_docker_dns {
    if $docker_dns =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ {
      # Allow Docker containers resolving using caching resolver running on docker host
      each(['tcp', 'udp']) |$proto| {
        ufw::allow { "dockerhost_ufw_allow_dns_53_${proto}":
          from  => '172.16.0.0/12',
          ip    => $docker_dns,
          port  => '53',
          proto => $proto,
        }
      }
    } else {
      notice("Can't set up firewall rules to allow v4-docker DNS to a v6 nameserver ($docker_dns)")
    }
  }

  if $manage_dockerhost_unbound {
    ensure_resource('class', 'sunet::unbound', {})

    file {
      '/etc/unbound/unbound.conf.d/unbound.conf':  # configuration to listen to the $docker_dns IP
        ensure  => file,
        path    => '/etc/unbound/unbound.conf.d/unbound.conf',
        mode    => '0644',
        content => template('sunet/dockerhost/unbound.conf.erb'),
        require => Package['unbound'],
        notify  => Service['unbound'],
        ;
    }
  }

}
